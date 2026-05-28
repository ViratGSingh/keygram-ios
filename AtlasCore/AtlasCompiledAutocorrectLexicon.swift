import Foundation

final class AtlasCompiledAutocorrectLexicon {
    enum LoadError: Error, CustomStringConvertible {
        case missingResource
        case invalidFormat(String)

        var description: String {
            switch self {
            case .missingResource:
                return "missing compiled autocorrect lexicon resource"
            case .invalidFormat(let reason):
                return "invalid compiled autocorrect lexicon: \(reason)"
            }
        }
    }

    private struct DeleteRecord {
        var hash: UInt64
        var start: Int
        var count: Int
    }

    private static let magic = Array("KGLEX001".utf8)
    private static let formatVersion: UInt32 = 1

    private let words: [String]
    private let frequencies: [Double]
    private let candidateIDs: [Int]
    private let deleteRecords: [DeleteRecord]
    private let deleteCandidateIDs: [Int]

    let diagnosticsDescription: String

    init(bundle: Bundle = .main, resourceName: String = "autocorrect_lexicon_v1") throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: "kglex") else {
            throw LoadError.missingResource
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        var reader = BinaryReader(data: data)
        let magic = try reader.readBytes(count: Self.magic.count)
        guard magic == Self.magic else {
            throw LoadError.invalidFormat("bad magic")
        }

        let version = try reader.readUInt32()
        guard version == Self.formatVersion else {
            throw LoadError.invalidFormat("unsupported version \(version)")
        }

        let wordCount = try reader.readCount("word count")
        let candidateCount = try reader.readCount("candidate count")
        let deleteEntryCount = try reader.readCount("delete entry count")
        let deleteCandidateCount = try reader.readCount("delete candidate count")
        let stringTableByteCount = try reader.readCount("string table byte count")
        let diagnosticsByteCount = try reader.readCount("diagnostics byte count")

        var wordRecords: [(offset: Int, length: Int, frequency: Double)] = []
        wordRecords.reserveCapacity(wordCount)
        for _ in 0..<wordCount {
            let offset = try reader.readCount("word offset")
            let length = Int(try reader.readUInt16())
            _ = try reader.readUInt16()
            let frequency = Double(try reader.readFloat32())
            wordRecords.append((offset, length, frequency))
        }

        var loadedCandidateIDs: [Int] = []
        loadedCandidateIDs.reserveCapacity(candidateCount)
        for _ in 0..<candidateCount {
            let id = try reader.readCount("candidate word id")
            guard id < wordCount else {
                throw LoadError.invalidFormat("candidate id out of range")
            }
            loadedCandidateIDs.append(id)
        }

        var loadedDeleteRecords: [DeleteRecord] = []
        loadedDeleteRecords.reserveCapacity(deleteEntryCount)
        for _ in 0..<deleteEntryCount {
            let hash = try reader.readUInt64()
            let start = try reader.readCount("delete candidate start")
            let count = try reader.readCount("delete candidate count")
            guard start <= deleteCandidateCount, start + count <= deleteCandidateCount else {
                throw LoadError.invalidFormat("delete candidate range out of bounds")
            }
            loadedDeleteRecords.append(DeleteRecord(hash: hash, start: start, count: count))
        }

        var loadedDeleteCandidateIDs: [Int] = []
        loadedDeleteCandidateIDs.reserveCapacity(deleteCandidateCount)
        for _ in 0..<deleteCandidateCount {
            let id = try reader.readCount("delete candidate word id")
            guard id < wordCount else {
                throw LoadError.invalidFormat("delete candidate id out of range")
            }
            loadedDeleteCandidateIDs.append(id)
        }

        let stringTable = try reader.readBytes(count: stringTableByteCount)
        var loadedWords: [String] = []
        var loadedFrequencies: [Double] = []
        loadedWords.reserveCapacity(wordCount)
        loadedFrequencies.reserveCapacity(wordCount)
        for record in wordRecords {
            guard record.offset <= stringTable.count,
                  record.offset + record.length <= stringTable.count
            else {
                throw LoadError.invalidFormat("word string range out of bounds")
            }
            let bytes = stringTable[record.offset..<(record.offset + record.length)]
            loadedWords.append(String(decoding: bytes, as: UTF8.self))
            loadedFrequencies.append(record.frequency)
        }

        for index in loadedWords.indices.dropFirst() where loadedWords[index - 1] > loadedWords[index] {
            throw LoadError.invalidFormat("word table must be sorted")
        }
        for index in loadedDeleteRecords.indices.dropFirst() where loadedDeleteRecords[index - 1].hash > loadedDeleteRecords[index].hash {
            throw LoadError.invalidFormat("delete records must be sorted")
        }

        let diagnosticsBytes = try reader.readBytes(count: diagnosticsByteCount)
        let diagnostics = String(decoding: diagnosticsBytes, as: UTF8.self)

        words = loadedWords
        frequencies = loadedFrequencies
        candidateIDs = loadedCandidateIDs
        deleteRecords = loadedDeleteRecords
        deleteCandidateIDs = loadedDeleteCandidateIDs
        diagnosticsDescription = "compiled=\(resourceName).kglex words=\(wordCount) candidates=\(candidateCount) deleteKeys=\(deleteEntryCount) deleteLinks=\(deleteCandidateCount); \(diagnostics)"
    }

    func contains(_ word: String) -> Bool {
        wordID(for: word) != nil
    }

    func frequency(for word: String) -> Double {
        guard let id = wordID(for: word) else { return 8 }
        return max(1, frequencies[id])
    }

    func completions(forNormalizedPrefix prefix: String, limit: Int) -> [String] {
        guard !prefix.isEmpty else { return [] }
        var results: [String] = []
        results.reserveCapacity(limit)
        for id in candidateIDs {
            let word = words[id]
            guard word != prefix, word.hasPrefix(prefix) else { continue }
            results.append(word)
            if results.count >= limit { break }
        }
        return results
    }

    func correctionCandidates(forNormalizedWord word: String, maxDistance: Int, limit: Int) -> [String] {
        var results: [(word: String, distance: Int)] = []
        results.reserveCapacity(limit)
        var seen = Set<Int>()

        for key in Self.deletionKeys(for: word, maxDeletes: min(maxDistance, 1)) {
            guard let record = deleteRecord(forHash: Self.stableHash(key)) else { continue }
            let end = record.start + record.count
            for candidateID in deleteCandidateIDs[record.start..<end] where seen.insert(candidateID).inserted {
                let candidate = words[candidateID]
                guard candidate != word, abs(candidate.count - word.count) <= maxDistance else { continue }
                guard let distance = AtlasSpellingMetrics.editDistance(candidate, word, maxDistance: maxDistance) else { continue }
                results.append((candidate, distance))
            }
        }

        return sortedCandidates(results, limit: limit)
    }

    private func sortedCandidates(_ results: [(word: String, distance: Int)], limit: Int) -> [String] {
        results
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return frequency(for: lhs.word) > frequency(for: rhs.word)
            }
            .prefix(limit)
            .map(\.word)
    }

    private func wordID(for word: String) -> Int? {
        var lowerBound = 0
        var upperBound = words.count

        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            let candidate = words[midpoint]
            if candidate == word {
                return midpoint
            }
            if candidate < word {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        return nil
    }

    private func deleteRecord(forHash hash: UInt64) -> DeleteRecord? {
        var lowerBound = 0
        var upperBound = deleteRecords.count

        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            let record = deleteRecords[midpoint]
            if record.hash == hash {
                return record
            }
            if record.hash < hash {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        return nil
    }

    private static func deletionKeys(for word: String, maxDeletes: Int) -> Set<String> {
        let characters = Array(word)
        guard !characters.isEmpty else { return [] }

        var keys: Set<String> = [word]
        var frontier: Set<String> = [word]
        guard maxDeletes > 0 else { return keys }

        for _ in 0..<maxDeletes {
            var next: Set<String> = []
            for value in frontier {
                let valueCharacters = Array(value)
                guard valueCharacters.count > 1 else { continue }
                for index in valueCharacters.indices {
                    var deleted = valueCharacters
                    deleted.remove(at: index)
                    let key = String(deleted)
                    if keys.insert(key).inserted {
                        next.insert(key)
                    }
                }
            }
            frontier = next
            if frontier.isEmpty { break }
        }

        return keys
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

private struct BinaryReader {
    private let data: Data
    private var offset = 0

    init(data: Data) {
        self.data = data
    }

    mutating func readBytes(count: Int) throws -> [UInt8] {
        guard count >= 0, offset + count <= data.count else {
            throw AtlasCompiledAutocorrectLexicon.LoadError.invalidFormat("unexpected end of file")
        }
        defer { offset += count }
        return Array(data[offset..<(offset + count)])
    }

    mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else {
            throw AtlasCompiledAutocorrectLexicon.LoadError.invalidFormat("unexpected end of file")
        }
        let value = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        offset += 2
        return value
    }

    mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw AtlasCompiledAutocorrectLexicon.LoadError.invalidFormat("unexpected end of file")
        }
        let value = UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
        offset += 4
        return value
    }

    mutating func readUInt64() throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw AtlasCompiledAutocorrectLexicon.LoadError.invalidFormat("unexpected end of file")
        }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        offset += 8
        return value
    }

    mutating func readFloat32() throws -> Float {
        Float(bitPattern: try readUInt32())
    }

    mutating func readCount(_ name: String) throws -> Int {
        let value = try readUInt32()
        guard let count = Int(exactly: value) else {
            throw AtlasCompiledAutocorrectLexicon.LoadError.invalidFormat("\(name) too large")
        }
        return count
    }
}
