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
    private static let headerByteCount = 36
    private static let wordRecordByteCount = 12
    private static let candidateIDByteCount = 4
    private static let deleteRecordByteCount = 16

    private let data: Data
    private let wordCount: Int
    private let candidateCount: Int
    private let deleteEntryCount: Int
    private let deleteCandidateCount: Int
    private let wordRecordsOffset: Int
    private let candidateIDsOffset: Int
    private let deleteRecordsOffset: Int
    private let deleteCandidateIDsOffset: Int
    private let stringTableOffset: Int
    private let stringTableByteCount: Int

    let diagnosticsDescription: String

    init(bundle: Bundle = .main, resourceName: String = "autocorrect_lexicon_v1") throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: "kglex") else {
            throw LoadError.missingResource
        }

        let mappedData = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard mappedData.count >= Self.headerByteCount else {
            throw LoadError.invalidFormat("file is smaller than header")
        }
        guard Array(mappedData[0..<Self.magic.count]) == Self.magic else {
            throw LoadError.invalidFormat("bad magic")
        }

        let version = Self.readUInt32(from: mappedData, at: 8)
        guard version == Self.formatVersion else {
            throw LoadError.invalidFormat("unsupported version \(version)")
        }

        let loadedWordCount = Int(Self.readUInt32(from: mappedData, at: 12))
        let loadedCandidateCount = Int(Self.readUInt32(from: mappedData, at: 16))
        let loadedDeleteEntryCount = Int(Self.readUInt32(from: mappedData, at: 20))
        let loadedDeleteCandidateCount = Int(Self.readUInt32(from: mappedData, at: 24))
        let loadedStringTableByteCount = Int(Self.readUInt32(from: mappedData, at: 28))
        let diagnosticsByteCount = Int(Self.readUInt32(from: mappedData, at: 32))

        let loadedWordRecordsOffset = Self.headerByteCount
        let loadedCandidateIDsOffset = try Self.checkedOffset(
            loadedWordRecordsOffset,
            adding: loadedWordCount,
            stride: Self.wordRecordByteCount
        )
        let loadedDeleteRecordsOffset = try Self.checkedOffset(
            loadedCandidateIDsOffset,
            adding: loadedCandidateCount,
            stride: Self.candidateIDByteCount
        )
        let loadedDeleteCandidateIDsOffset = try Self.checkedOffset(
            loadedDeleteRecordsOffset,
            adding: loadedDeleteEntryCount,
            stride: Self.deleteRecordByteCount
        )
        let loadedStringTableOffset = try Self.checkedOffset(
            loadedDeleteCandidateIDsOffset,
            adding: loadedDeleteCandidateCount,
            stride: Self.candidateIDByteCount
        )
        let diagnosticsOffset = try Self.checkedOffset(
            loadedStringTableOffset,
            adding: loadedStringTableByteCount,
            stride: 1
        )
        let expectedByteCount = try Self.checkedOffset(
            diagnosticsOffset,
            adding: diagnosticsByteCount,
            stride: 1
        )
        guard expectedByteCount == mappedData.count else {
            throw LoadError.invalidFormat("unexpected file size")
        }

        data = mappedData
        wordCount = loadedWordCount
        candidateCount = loadedCandidateCount
        deleteEntryCount = loadedDeleteEntryCount
        deleteCandidateCount = loadedDeleteCandidateCount
        wordRecordsOffset = loadedWordRecordsOffset
        candidateIDsOffset = loadedCandidateIDsOffset
        deleteRecordsOffset = loadedDeleteRecordsOffset
        deleteCandidateIDsOffset = loadedDeleteCandidateIDsOffset
        stringTableOffset = loadedStringTableOffset
        stringTableByteCount = loadedStringTableByteCount

        let diagnostics = String(decoding: data[diagnosticsOffset..<expectedByteCount], as: UTF8.self)
        diagnosticsDescription = "compiled=\(resourceName).kglex words=\(wordCount) candidates=\(candidateCount) deleteKeys=\(deleteEntryCount) deleteLinks=\(deleteCandidateCount); \(diagnostics)"
        try validateIndexes()
    }

    func contains(_ word: String) -> Bool {
        wordID(for: word) != nil
    }

    func frequency(for word: String) -> Double {
        guard let id = wordID(for: word) else { return 8 }
        return max(1, frequency(forWordID: id))
    }

    func rankedCandidates(limit: Int) -> [(word: String, frequency: Double)] {
        guard limit > 0 else { return [] }
        var result: [(word: String, frequency: Double)] = []
        result.reserveCapacity(min(limit, candidateCount))
        for index in 0..<min(limit, candidateCount) {
            let id = candidateID(at: index)
            result.append((word(at: id), frequency(forWordID: id)))
        }
        return result
    }

    func candidateRank(for word: String) -> Int? {
        guard let id = wordID(for: word) else { return nil }
        for index in 0..<candidateCount where candidateID(at: index) == id {
            return index + 1
        }
        return nil
    }

    func completions(forNormalizedPrefix prefix: String, limit: Int) -> [String] {
        guard !prefix.isEmpty, limit > 0 else { return [] }
        var results: [String] = []
        results.reserveCapacity(limit)
        for index in 0..<candidateCount {
            let word = word(at: candidateID(at: index))
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
            for index in record.start..<end {
                let candidateID = deleteCandidateID(at: index)
                guard seen.insert(candidateID).inserted else { continue }
                let candidate = self.word(at: candidateID)
                guard candidate != word, abs(candidate.count - word.count) <= maxDistance else { continue }
                guard let distance = AtlasSpellingMetrics.editDistance(candidate, word, maxDistance: maxDistance) else { continue }
                results.append((candidate, distance))
            }
        }

        return results
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return frequency(for: lhs.word) > frequency(for: rhs.word)
            }
            .prefix(limit)
            .map(\.word)
    }

    private func validateIndexes() throws {
        var previousWord: String?
        for id in 0..<wordCount {
            let recordOffset = wordRecordsOffset + id * Self.wordRecordByteCount
            let offset = Int(Self.readUInt32(from: data, at: recordOffset))
            let length = Int(Self.readUInt16(from: data, at: recordOffset + 4))
            guard offset <= stringTableByteCount, offset + length <= stringTableByteCount else {
                throw LoadError.invalidFormat("word string range out of bounds")
            }
            let word = word(at: id)
            if let previousWord, previousWord > word {
                throw LoadError.invalidFormat("word table must be sorted")
            }
            previousWord = word
        }

        for index in 0..<candidateCount where candidateID(at: index) >= wordCount {
            throw LoadError.invalidFormat("candidate id out of range")
        }

        var previousHash: UInt64?
        for index in 0..<deleteEntryCount {
            let record = deleteRecord(at: index)
            guard record.start <= deleteCandidateCount,
                  record.start + record.count <= deleteCandidateCount
            else {
                throw LoadError.invalidFormat("delete candidate range out of bounds")
            }
            if let previousHash, previousHash > record.hash {
                throw LoadError.invalidFormat("delete records must be sorted")
            }
            previousHash = record.hash
        }

        for index in 0..<deleteCandidateCount where deleteCandidateID(at: index) >= wordCount {
            throw LoadError.invalidFormat("delete candidate id out of range")
        }
    }

    private func wordID(for word: String) -> Int? {
        var lowerBound = 0
        var upperBound = wordCount

        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            let candidate = self.word(at: midpoint)
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
        var upperBound = deleteEntryCount

        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            let record = deleteRecord(at: midpoint)
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

    private func word(at id: Int) -> String {
        let recordOffset = wordRecordsOffset + id * Self.wordRecordByteCount
        let offset = Int(Self.readUInt32(from: data, at: recordOffset))
        let length = Int(Self.readUInt16(from: data, at: recordOffset + 4))
        let start = stringTableOffset + offset
        return String(decoding: data[start..<(start + length)], as: UTF8.self)
    }

    private func frequency(forWordID id: Int) -> Double {
        let offset = wordRecordsOffset + id * Self.wordRecordByteCount + 8
        return Double(Float(bitPattern: Self.readUInt32(from: data, at: offset)))
    }

    private func candidateID(at index: Int) -> Int {
        Int(Self.readUInt32(from: data, at: candidateIDsOffset + index * Self.candidateIDByteCount))
    }

    private func deleteRecord(at index: Int) -> DeleteRecord {
        let offset = deleteRecordsOffset + index * Self.deleteRecordByteCount
        return DeleteRecord(
            hash: Self.readUInt64(from: data, at: offset),
            start: Int(Self.readUInt32(from: data, at: offset + 8)),
            count: Int(Self.readUInt32(from: data, at: offset + 12))
        )
    }

    private func deleteCandidateID(at index: Int) -> Int {
        Int(Self.readUInt32(from: data, at: deleteCandidateIDsOffset + index * Self.candidateIDByteCount))
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

    private static func checkedOffset(_ base: Int, adding count: Int, stride: Int) throws -> Int {
        let (byteCount, multiplicationOverflow) = count.multipliedReportingOverflow(by: stride)
        let (result, additionOverflow) = base.addingReportingOverflow(byteCount)
        guard !multiplicationOverflow, !additionOverflow else {
            throw LoadError.invalidFormat("section size overflow")
        }
        return result
    }

    private static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func readUInt64(from data: Data, at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        return value
    }
}
