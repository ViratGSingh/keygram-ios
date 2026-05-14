import Foundation

#if canImport(OnnxRuntimeBindings)
import OnnxRuntimeBindings

final class AtlasONNXModelRuntime: AtlasModelRuntime {
    private enum InputName {
        static let inputIDs = "input_ids"
        static let positionID = "position_id"
        static func keyCache(_ index: Int) -> String { "k\(index)_cache" }
        static func valueCache(_ index: Int) -> String { "v\(index)_cache" }
        static func glaState(_ index: Int) -> String { "gla_state_\(index)" }
    }

    private enum OutputName {
        static let logits = "logits"
        static func keyCache(_ index: Int) -> String { "new_k\(index)_cache" }
        static func valueCache(_ index: Int) -> String { "new_v\(index)_cache" }
        static func glaState(_ index: Int) -> String { "new_gla_state_\(index)" }
    }

    private let env: ORTEnv
    private let session: ORTSession
    private let outputNames: Set<String>

    init(bundle: Bundle = .main) throws {
        let modelBundle = try AtlasModelBundle.resolve(in: bundle)
        env = try ORTEnv(loggingLevel: .warning)

        let options = try ORTSessionOptions()
        session = try ORTSession(env: env, modelPath: modelBundle.modelURL.path, sessionOptions: options)

        var names: Set<String> = [OutputName.logits]
        for index in 0..<AtlasConfiguration.attentionLayerCount {
            names.insert(OutputName.keyCache(index))
            names.insert(OutputName.valueCache(index))
        }
        for index in 0..<AtlasConfiguration.glaLayerCount {
            names.insert(OutputName.glaState(index))
        }
        outputNames = names
    }

    func step(_ input: AtlasModelStepInput) throws -> AtlasModelStepOutput {
        var inputs: [String: ORTValue] = [
            InputName.inputIDs: try int64Tensor([input.tokenID], shape: AtlasTensorShapes.inputIDs),
            InputName.positionID: try int64Tensor([input.positionID], shape: AtlasTensorShapes.positionID)
        ]

        for index in 0..<AtlasConfiguration.attentionLayerCount {
            inputs[InputName.keyCache(index)] = try floatTensor(input.kvCache.keys[index])
            inputs[InputName.valueCache(index)] = try floatTensor(input.kvCache.values[index])
        }

        for index in 0..<AtlasConfiguration.glaLayerCount {
            inputs[InputName.glaState(index)] = try floatTensor(input.glaState.layers[index])
        }

        let outputs = try session.run(withInputs: inputs, outputNames: outputNames, runOptions: nil)
        guard let logitsValue = outputs[OutputName.logits] else {
            throw AtlasONNXModelRuntimeError.missingOutput(OutputName.logits)
        }

        var kvCache = AtlasKVCache()
        for index in 0..<AtlasConfiguration.attentionLayerCount {
            guard let keyValue = outputs[OutputName.keyCache(index)] else {
                throw AtlasONNXModelRuntimeError.missingOutput(OutputName.keyCache(index))
            }
            guard let valueValue = outputs[OutputName.valueCache(index)] else {
                throw AtlasONNXModelRuntimeError.missingOutput(OutputName.valueCache(index))
            }
            kvCache.keys[index] = try atlasTensor(from: keyValue)
            kvCache.values[index] = try atlasTensor(from: valueValue)
        }

        var glaState = AtlasGLAState.empty()
        for index in 0..<AtlasConfiguration.glaLayerCount {
            guard let value = outputs[OutputName.glaState(index)] else {
                throw AtlasONNXModelRuntimeError.missingOutput(OutputName.glaState(index))
            }
            glaState.layers[index] = try atlasTensor(from: value)
        }

        return AtlasModelStepOutput(
            logits: try floats(from: logitsValue),
            kvCache: kvCache,
            glaState: glaState
        )
    }

    private func int64Tensor(_ values: [Int64], shape: [Int]) throws -> ORTValue {
        let data = NSMutableData(bytes: values, length: values.count * MemoryLayout<Int64>.stride)
        return try ORTValue(tensorData: data, elementType: .int64, shape: shape.map(NSNumber.init(value:)))
    }

    private func floatTensor(_ tensor: AtlasFloatTensor) throws -> ORTValue {
        let data = NSMutableData(data: tensor.data)
        return try ORTValue(tensorData: data, elementType: .float, shape: tensor.shape.map(NSNumber.init(value:)))
    }

    private func atlasTensor(from value: ORTValue) throws -> AtlasFloatTensor {
        let info = try value.tensorTypeAndShapeInfo()
        let shape = info.shape.map { $0.intValue }
        let data = try value.tensorData() as Data
        return AtlasFloatTensor(data: data, shape: shape)
    }

    private func floats(from value: ORTValue) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}

enum AtlasONNXModelRuntimeError: LocalizedError {
    case missingOutput(String)

    var errorDescription: String? {
        switch self {
        case .missingOutput(let name):
            return "ATLAS ONNX output missing: \(name)"
        }
    }
}

#else

final class AtlasONNXModelRuntime: AtlasModelRuntime {
    init(bundle: Bundle = .main) throws {
        throw AtlasONNXModelRuntimeError.onnxRuntimeUnavailable
    }

    func step(_ input: AtlasModelStepInput) throws -> AtlasModelStepOutput {
        throw AtlasONNXModelRuntimeError.onnxRuntimeUnavailable
    }
}

enum AtlasONNXModelRuntimeError: LocalizedError {
    case onnxRuntimeUnavailable

    var errorDescription: String? {
        "ONNX Runtime is not linked into the AtlasKeyboard target."
    }
}

#endif

