#!/usr/bin/env python3
import json
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path


MAGIC = b"KGLEX001"
VERSION = 1


def normalized_word(raw):
    word = raw.strip().lower()
    if not word or len(word) > 64:
        return None
    if not re.fullmatch(r"[a-z']*[a-z][a-z']*", word):
        return None
    return word


def is_usable_word(word):
    return 1 <= len(word) <= 24 and normalized_word(word) == word


def is_usable_candidate(word):
    return len(word) >= 2 and is_usable_word(word)


def ordered_unique(words):
    seen = set()
    result = []
    for word in words:
        if word not in seen:
            seen.add(word)
            result.append(word)
    return result


def load_word_list(path):
    data = path.read_text(encoding="utf-8")
    stripped = data.lstrip()
    if stripped.startswith("["):
        raw_words = json.loads(data)
    else:
        raw_words = data.splitlines()
    return [word for raw in raw_words if (word := normalized_word(str(raw)))]


SYSTEM_DICTIONARY_PATH = Path("/usr/share/dict/words")


def load_english_authority(path=SYSTEM_DICTIONARY_PATH):
    """A clean English wordlist used to decide which model tokens are non-English.

    The app's own ``english_words.bin`` and ``frequency_table.bin`` are both built
    from the Hinglish corpus and contain romanized Hindi, so they can't be used to
    identify English. The system dictionary (web2) is pure English.
    """
    if not path.exists():
        return None
    words = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        word = normalized_word(line)
        if word is not None:
            words.add(word)
    return words or None


def load_protected_words(model_path, english_authority):
    """Whole-word tokens the next-word model knows that are not English words.

    These are the romanized-Hindi (and other non-English) words the neural model
    predicts. We mark them as protected so autocorrect never rewrites them to a
    nearby English word. Modern-English tokens the system dictionary happens to miss
    may slip in, which is harmless: protected words stay in the correction-candidate
    pool, so a genuine misspelling still corrects toward them.
    """
    if not model_path.exists():
        print(f"warning: {model_path} missing; skipping Hinglish protection")
        return []
    if english_authority is None:
        print(
            f"warning: {SYSTEM_DICTIONARY_PATH} missing; cannot separate Hindi from "
            "English, skipping Hinglish protection"
        )
        return []
    try:
        import sentencepiece as spm
    except ImportError:
        print("warning: sentencepiece not installed; skipping Hinglish protection")
        return []

    processor = spm.SentencePieceProcessor()
    processor.load(str(model_path))

    protected = set()
    for token_id in range(processor.get_piece_size()):
        piece = processor.id_to_piece(token_id)
        if not piece.startswith("▁"):  # only whole-word (word-boundary) tokens
            continue
        word = normalized_word(piece.replace("▁", ""))
        if word is None or len(word) < 2 or word in english_authority:
            continue
        protected.add(word)
    return sorted(protected)


def load_frequency_table(path):
    raw_table = json.loads(path.read_text(encoding="utf-8"))
    table = {}
    for raw_word, raw_value in raw_table.items():
        word = normalized_word(raw_word)
        if word is None:
            continue
        table[word] = float(raw_value)

    if not table:
        return table

    minimum = min(table.values())
    maximum = max(table.values())
    if minimum <= 1 and maximum <= len(table) * 10:
        return {word: max(1.0, maximum - value + 1.0) for word, value in table.items()}
    return table


def swift_literal_strings(path, declaration_name):
    text = path.read_text(encoding="utf-8")
    pattern = rf"{re.escape(declaration_name)}[^=]*=\s*\[(.*?)\n\s*\]"
    match = re.search(pattern, text, flags=re.S)
    if not match:
        raise RuntimeError(f"could not find Swift literal {declaration_name} in {path}")
    return re.findall(r'"([^"]+)"', match.group(1))


def swift_frequency_literal(path):
    text = path.read_text(encoding="utf-8")
    pattern = r"seedFrequencies[^=]*=\s*\[(.*?)\n\s*\]"
    match = re.search(pattern, text, flags=re.S)
    if not match:
        raise RuntimeError(f"could not find seedFrequencies in {path}")
    return {
        word: float(value.replace("_", ""))
        for word, value in re.findall(r'"([^"]+)":\s*([0-9_]+(?:\.[0-9_]+)?)', match.group(1))
    }


def deletion_keys(word):
    keys = {word}
    if len(word) <= 1:
        return keys
    for index in range(len(word)):
        keys.add(word[:index] + word[index + 1 :])
    return keys


def stable_hash(value):
    result = 0xCBF29CE484222325
    for byte in value.encode("utf-8"):
        result ^= byte
        result = (result * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return result


def build(root):
    keyboard_dir = root / "AtlasKeyboard"
    core_dir = root / "AtlasCore"
    engine_path = core_dir / "AtlasAutocorrectEngine.swift"
    engram_path = core_dir / "Engram.swift"

    frequency_table = load_frequency_table(keyboard_dir / "frequency_table.bin")
    seed_frequencies = swift_frequency_literal(engine_path)
    additional_common_words = swift_literal_strings(engine_path, "additionalCommonWords")
    common_words = swift_literal_strings(engram_path, "blockedWords")

    merged_frequencies = dict(seed_frequencies)
    for word, frequency in frequency_table.items():
        merged_frequencies[word] = max(merged_frequencies.get(word, 0), frequency)
    for word in common_words:
        merged_frequencies[word] = max(merged_frequencies.get(word, 0), 22_000.0)
    for word in additional_common_words:
        merged_frequencies[word] = max(merged_frequencies.get(word, 0), 16_000.0)

    imported_words = load_word_list(keyboard_dir / "english_words.bin")

    # Romanized-Hindi / non-English words the next-word model knows. Any whole-word model
    # token absent from the clean system English dictionary is added to the lexicon and
    # flagged protected so autocorrect leaves it alone.
    protected_words = [
        word
        for word in load_protected_words(
            keyboard_dir / "Resources" / "v3_spm.model", load_english_authority()
        )
        if is_usable_word(word)
    ]
    protected_word_set = set(protected_words)

    known_words = {
        word for word in imported_words + list(merged_frequencies.keys()) if is_usable_word(word)
    }
    dictionary_words = sorted(known_words | protected_word_set)
    dictionary_word_set = set(dictionary_words)

    imported_candidate_words = load_word_list(keyboard_dir / "english_bktree_words.bin")
    candidate_words = [
        word
        for word in ordered_unique(
            [
                word
                for word in imported_candidate_words
                + list(seed_frequencies.keys())
                + additional_common_words
                + common_words
                if is_usable_candidate(word)
            ]
        )
        if word in dictionary_word_set or word in merged_frequencies
    ]

    candidate_count = len(candidate_words)
    for index, word in enumerate(candidate_words):
        rank_score = float(max(1, candidate_count - index))
        merged_frequencies[word] = max(merged_frequencies.get(word, 0), rank_score)

    word_ids = {word: index for index, word in enumerate(dictionary_words)}
    candidate_ids = [word_ids[word] for word in candidate_words]

    delete_index = defaultdict(list)
    for word in candidate_words:
        word_id = word_ids[word]
        for key in deletion_keys(word):
            delete_index[stable_hash(key)].append(word_id)

    delete_records = []
    delete_candidate_ids = []
    for key_hash in sorted(delete_index):
        ids = delete_index[key_hash]
        start = len(delete_candidate_ids)
        delete_candidate_ids.extend(ids)
        delete_records.append((key_hash, start, len(ids)))

    WORD_FLAG_PROTECTED = 1
    string_table = bytearray()
    word_records = []
    for word in dictionary_words:
        encoded = word.encode("utf-8")
        flags = WORD_FLAG_PROTECTED if word in protected_word_set else 0
        word_records.append(
            (len(string_table), len(encoded), flags, float(merged_frequencies.get(word, 8.0)))
        )
        string_table.extend(encoded)

    top_words = sorted(frequency_table.items(), key=lambda item: (-item[1], item[0]))[:5]
    diagnostics = (
        f"dictionary=english_words.bin entries={len(imported_words)} usable={len(dictionary_words)}; "
        f"candidates=english_bktree_words.bin entries={len(imported_candidate_words)} usable={len(candidate_words)}; "
        f"protected=v3_spm.model words={len(protected_words)}; "
        f"frequency_table.bin loaded entries={len(frequency_table)} top={','.join(word for word, _ in top_words)}"
    ).encode("utf-8")

    output = bytearray()
    output.extend(MAGIC)
    output.extend(
        struct.pack(
            "<IIIIIII",
            VERSION,
            len(dictionary_words),
            len(candidate_ids),
            len(delete_records),
            len(delete_candidate_ids),
            len(string_table),
            len(diagnostics),
        )
    )
    for offset, length, flags, frequency in word_records:
        output.extend(struct.pack("<IHHf", offset, length, flags, frequency))
    for word_id in candidate_ids:
        output.extend(struct.pack("<I", word_id))
    for key_hash, start, count in delete_records:
        output.extend(struct.pack("<QII", key_hash, start, count))
    for word_id in delete_candidate_ids:
        output.extend(struct.pack("<I", word_id))
    output.extend(string_table)
    output.extend(diagnostics)

    output_path = keyboard_dir / "autocorrect_lexicon_v1.kglex"
    output_path.write_bytes(output)
    print(f"wrote {output_path}")
    print(diagnostics.decode("utf-8"))
    print(
        f"compiled words={len(dictionary_words)} candidates={len(candidate_ids)} "
        f"deleteKeys={len(delete_records)} deleteLinks={len(delete_candidate_ids)} "
        f"bytes={len(output)}"
    )


if __name__ == "__main__":
    root_arg = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    build(root_arg.resolve())
