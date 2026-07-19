import Foundation

struct AtlasModelBundle {
    let modelURL: URL
    let tokenizerURL: URL

    static func resolve(in bundle: Bundle = .main) throws -> AtlasModelBundle {
        let modelURL = try resolveResource(
            candidates: [
                "atlas_general_keyboard_q8",
                "atlas_v3_keyboard_q8",
                "altaas_v3_lkeybaord_q8",
                "atlas_v2_keyboard_q8",
                "atlas_keyboard_q8"
            ],
            extension: "onnx",
            in: bundle
        )
        let tokenizerURL = try resolveResource(
            candidates: ["general_spm", "v3_spm", "v2_spm"],
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
            if let url = bundle.url(forResource: candidate, withExtension: resourceExtension, subdirectory: "Resources") {
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
