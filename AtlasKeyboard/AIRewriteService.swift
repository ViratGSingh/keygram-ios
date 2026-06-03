import Foundation

enum AIRewriteStyle: String, CaseIterable {
    case flirty
    case work
    case friends
    case betterPrompt

    var title: String {
        switch self {
        case .flirty:
            return "Flirty"
        case .work:
            return "Work"
        case .friends:
            return "Friends"
        case .betterPrompt:
            return "Prompt"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .flirty:
            return "Flirty rewrite"
        case .work:
            return "Professional rewrite"
        case .friends:
            return "Casual rewrite"
        case .betterPrompt:
            return "Better prompt rewrite"
        }
    }

    var temperature: Double {
        switch self {
        case .flirty, .friends:
            return 0.55
        case .work, .betterPrompt:
            return 0.25
        }
    }

    var systemPrompt: String {
        let base = """
        You rewrite user-provided text. Preserve the user's meaning, intent, language, names, dates, numbers, and factual claims. Never invent facts, commitments, events, or details the user did not state. Do not add explanations, alternatives, labels, markdown, quotes, or preambles. Return only the rewritten text.
        """

        switch self {
        case .flirty:
            return base + "\nStyle: warm, playful, lightly affectionate, natural texting tone for someone the user likes. Avoid cringe, pressure, explicit sexual content, or over-the-top compliments."
        case .work:
            return base + "\nStyle: clear, polite, professional, concise. Remove slang and casual shorthand. Keep it suitable for workplace chat or email."
        case .friends:
            return base + "\nStyle: relaxed, friendly, natural casual texting. Keep it human and not polished like corporate copy."
        case .betterPrompt:
            return base + "\nStyle: turn the request into a clear, structured LLM prompt. Preserve the user's goal and constraints. Add structure only when it clarifies the existing request; do not invent missing requirements."
        }
    }
}

final class AIRewriteService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidEndpoint
        case invalidResponse
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenRouter API key"
            case .invalidEndpoint:
                return "Invalid OpenRouter endpoint"
            case .invalidResponse:
                return "Invalid AI response"
            case .emptyResponse:
                return "Empty AI response"
            }
        }
    }

    private struct ChatRequest: Encodable {
        var model: String
        var messages: [Message]
        var temperature: Double
        var maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    private struct Message: Codable {
        var role: String
        var content: String
    }

    private struct ChatResponse: Decodable {
        var choices: [Choice]

        struct Choice: Decodable {
            var message: Message?
        }
    }

    private let session: URLSession
    private let configuration: AIRewriteConfiguration

    init(configuration: AIRewriteConfiguration = .load()) {
        self.configuration = configuration
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout
        sessionConfiguration.waitsForConnectivity = false
        self.session = URLSession(configuration: sessionConfiguration)
    }

    func rewrite(text: String, style: AIRewriteStyle, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            completion(.failure(ServiceError.missingAPIKey))
            return
        }

        guard let endpoint = URL(string: configuration.endpoint), endpoint.scheme != nil else {
            completion(.failure(ServiceError.invalidEndpoint))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Keygram", forHTTPHeaderField: "X-Title")
        if let referrer = configuration.httpReferrer, !referrer.isEmpty {
            request.setValue(referrer, forHTTPHeaderField: "HTTP-Referer")
        }

        let body = ChatRequest(
            model: configuration.model,
            messages: [
                Message(role: "system", content: style.systemPrompt),
                Message(role: "user", content: text)
            ],
            temperature: style.temperature,
            maxTokens: maxTokens(for: text)
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let data
            else {
                completion(.failure(ServiceError.invalidResponse))
                return
            }

            Task { @MainActor in
                do {
                    let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                    let output = decoded.choices.first?.message?.content ?? ""
                    let cleaned = Self.cleanRewrite(output)
                    guard !cleaned.isEmpty else {
                        completion(.failure(ServiceError.emptyResponse))
                        return
                    }
                    completion(.success(cleaned))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func maxTokens(for text: String) -> Int {
        let approximateInputTokens = max(32, text.count / 4)
        return min(800, max(128, approximateInputTokens * 3))
    }

    private static func cleanRewrite(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```text", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if cleaned.count >= 2,
           let first = cleaned.first,
           let last = cleaned.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            cleaned.removeFirst()
            cleaned.removeLast()
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned
    }
}

struct AIRewriteConfiguration {
    var apiKey: String?
    var endpoint: String
    var model: String
    var timeout: TimeInterval
    var httpReferrer: String?

    static func load() -> AIRewriteConfiguration {
        let values = bundledDotEnv().merging(ProcessInfo.processInfo.environment) { _, environment in
            environment
        }
        let bundle = Bundle.main

        return AIRewriteConfiguration(
            apiKey: values["OPENROUTER_API_KEY"] ?? bundle.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String,
            endpoint: values["OPENROUTER_ENDPOINT"]
                ?? bundle.object(forInfoDictionaryKey: "OPENROUTER_ENDPOINT") as? String
                ?? "https://openrouter.ai/api/v1/chat/completions",
            model: values["OPENROUTER_MODEL"]
                ?? bundle.object(forInfoDictionaryKey: "OPENROUTER_MODEL") as? String
                ?? "openai/gpt-4o-mini",
            timeout: TimeInterval(values["OPENROUTER_TIMEOUT_SECONDS"] ?? "") ?? 8,
            httpReferrer: values["OPENROUTER_HTTP_REFERER"] ?? bundle.object(forInfoDictionaryKey: "OPENROUTER_HTTP_REFERER") as? String
        )
    }

    private static func bundledDotEnv() -> [String: String] {
        guard let url = Bundle.main.url(forResource: ".env", withExtension: nil),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return [:]
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                      let separator = trimmed.firstIndex(of: "=")
                else {
                    return
                }
                let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
                var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                if value.count >= 2,
                   let first = value.first,
                   let last = value.last,
                   (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                    value.removeFirst()
                    value.removeLast()
                }
                result[key] = value
            }
    }
}
