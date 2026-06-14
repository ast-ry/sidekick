import Foundation

struct LMStudioRequest {
    let endpoint: String
    let model: String
    let apiFormat: SidekickViewModel.APIFormat
    let systemPrompt: String
    let userPrompt: String
    let screenshotPNGData: Data?
}

final class LMStudioService {
    func send(request: LMStudioRequest) async throws -> String {
        guard let url = URL(string: normalizedEndpoint(from: request.endpoint, format: request.apiFormat)) else {
            throw SidekickError.invalidEndpoint
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch request.apiFormat {
        case .chatCompletions:
            urlRequest.httpBody = try JSONEncoder().encode(buildChatPayload(from: request))
        case .responses:
            urlRequest.httpBody = try JSONEncoder().encode(buildResponsesPayload(from: request))
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable response)"
            throw SidekickError.remoteFailure(body)
        }

        switch request.apiFormat {
        case .chatCompletions:
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            return decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No content returned."
        case .responses:
            let decoded = try JSONDecoder().decode(ResponsesAPIResponse.self, from: data)
            return decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? decoded.output.compactMap { item in
                    item.content.compactMap(\.text).joined(separator: "\n")
                }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
                ?? "No content returned."
        }
    }

    private func normalizedEndpoint(from endpoint: String, format: SidekickViewModel.APIFormat) -> String {
        switch format {
        case .chatCompletions:
            if endpoint.hasSuffix("/v1/chat/completions") { return endpoint }
            if endpoint.hasSuffix("/v1/responses") {
                return String(endpoint.dropLast("/responses".count)) + "/chat/completions"
            }
            return endpoint
        case .responses:
            if endpoint.hasSuffix("/v1/responses") { return endpoint }
            if endpoint.hasSuffix("/v1/chat/completions") {
                return String(endpoint.dropLast("/chat/completions".count)) + "/responses"
            }
            return endpoint
        }
    }

    private func buildChatPayload(from request: LMStudioRequest) -> ChatCompletionRequest {
        let userContent: [ChatMessage.Content]

        if let screenshotPNGData = request.screenshotPNGData {
            let imageURL = "data:image/png;base64,\(screenshotPNGData.base64EncodedString())"
            userContent = [
                .text(request.userPrompt),
                .imageURL(ImageURLContent(url: imageURL)),
            ]
        } else {
            userContent = [.text(request.userPrompt)]
        }

        return ChatCompletionRequest(
            model: request.model,
            messages: [
                ChatMessage(role: "system", content: [.text(request.systemPrompt)]),
                ChatMessage(role: "user", content: userContent),
            ],
            temperature: 0.2
        )
    }

    private func buildResponsesPayload(from request: LMStudioRequest) -> ResponsesAPIRequest {
        let userContent: [ResponsesAPIRequest.Input.Content]

        if let screenshotPNGData = request.screenshotPNGData {
            let imageURL = "data:image/png;base64,\(screenshotPNGData.base64EncodedString())"
            userContent = [
                .inputText(request.userPrompt),
                .inputImage(imageURL),
            ]
        } else {
            userContent = [.inputText(request.userPrompt)]
        }

        return ResponsesAPIRequest(
            model: request.model,
            input: [
                .init(role: "system", content: [.inputText(request.systemPrompt)]),
                .init(role: "user", content: userContent),
            ],
            temperature: 0.2
        )
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Encodable {
    let role: String
    let content: [Content]

    enum Content: Encodable {
        case text(String)
        case imageURL(ImageURLContent)

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let string):
                try container.encode("text", forKey: .type)
                try container.encode(string, forKey: .text)
            case .imageURL(let payload):
                try container.encode("image_url", forKey: .type)
                try container.encode(payload, forKey: .imageURL)
            }
        }
    }
}

private struct ImageURLContent: Encodable {
    let url: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

private struct ResponsesAPIRequest: Encodable {
    let model: String
    let input: [Input]
    let temperature: Double

    struct Input: Encodable {
        let role: String
        let content: [Content]

        enum Content: Encodable {
            case inputText(String)
            case inputImage(String)

            private enum CodingKeys: String, CodingKey {
                case type
                case text
                case imageURL = "image_url"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .inputText(let text):
                    try container.encode("input_text", forKey: .type)
                    try container.encode(text, forKey: .text)
                case .inputImage(let imageURL):
                    try container.encode("input_image", forKey: .type)
                    try container.encode(imageURL, forKey: .imageURL)
                }
            }
        }
    }
}

private struct ResponsesAPIResponse: Decodable {
    let outputText: String?
    let output: [OutputItem]

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    struct OutputItem: Decodable {
        let content: [ContentItem]
    }

    struct ContentItem: Decodable {
        let text: String?
    }
}
