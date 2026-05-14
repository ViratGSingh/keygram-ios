import Foundation

struct AtlasSession: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var avatarSeed: String?
    var updatedAt: Date
    var glaState: AtlasGLAState
    var engram: Engram

    static let defaultName = "You"

    static func fresh(name: String) -> AtlasSession {
        fresh(name: name, avatarSeed: nil)
    }

    static func fresh(name: String, avatarSeed: String?) -> AtlasSession {
        AtlasSession(
            id: UUID(),
            name: name,
            avatarSeed: avatarSeed ?? name,
            updatedAt: Date(),
            glaState: AtlasGLAState.empty(),
            engram: Engram()
        )
    }

    var displayInitials: String {
        let parts = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        let initials = parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "AT" : initials
    }

    var avatarHue: Double {
        let source = avatarSeed ?? name
        let total = source.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 360 }
        return Double(total) / 360.0
    }
}

struct AtlasGLAState: Codable, Equatable {
    var layers: [AtlasFloatTensor]

    static func empty() -> AtlasGLAState {
        AtlasGLAState(
            layers: (0..<AtlasConfiguration.glaLayerCount).map { _ in
                AtlasFloatTensor.zeros(shape: AtlasTensorShapes.glaState)
            }
        )
    }

    var isCompatibleWithCurrentModel: Bool {
        layers.count == AtlasConfiguration.glaLayerCount
            && layers.allSatisfy { $0.hasShape(AtlasTensorShapes.glaState) }
    }
}

struct AtlasFloatTensor: Codable, Equatable {
    var data: Data
    var shape: [Int]

    static func zeros(shape: [Int]) -> AtlasFloatTensor {
        let byteCount = shape.reduce(1, *) * MemoryLayout<Float>.stride
        return AtlasFloatTensor(data: Data(count: byteCount), shape: shape)
    }

    static func emptyKV() -> AtlasFloatTensor {
        AtlasFloatTensor(data: Data(), shape: AtlasTensorShapes.emptyKV)
    }

    func hasShape(_ expectedShape: [Int]) -> Bool {
        shape == expectedShape
            && data.count == expectedShape.reduce(1, *) * MemoryLayout<Float>.stride
    }
}

enum AtlasTensorShapes {
    static let inputIDs = [1, 1]
    static let positionID = [1]
    static let emptyKV = [1, 4, 0, 64]
    static let glaState = [1, 4, 64, 128]
}
