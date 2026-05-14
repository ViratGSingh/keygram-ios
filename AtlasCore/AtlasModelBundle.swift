import Foundation

struct AtlasModelBundle {
    let modelURL: URL
    let tokenizerURL: URL

    static func resolve(in bundle: Bundle = .main) throws -> AtlasModelBundle {
        let modelURL = try resolveResource(
            candidates: ["atlas_v2_keyboard_q8", "atlas_keyboard_q8"],
            extension: "onnx",
            in: bundle
        )
        let tokenizerURL = try resolveResource(
            candidates: ["v2_spm", "v3_spm"],
            extension: "model",
            in: bundle
        )

        return AtlasModelBundle(modelURL: modelURL, tokenizerURL: tokenizerURL)
    }

    private static func resolveResource(candidates: [String], extension resourceExtension: String, in bundle: Bundle) throws -> URL {
        for candidate in candidates {
            if let url = bundle.url(forResource: candidate, withExtension: resourceExtension) {
                return url
            }
        }

        let names = candidates.map { "\($0).\(resourceExtension)" }.joined(separator: " or ")
        throw AtlasModelBundleError.missingResource(names)
    }
}

enum AtlasModelBundleError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing bundled ATLAS resource: \(name)"
        }
    }
}
