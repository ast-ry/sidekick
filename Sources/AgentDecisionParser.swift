import Foundation

enum AgentDecisionParser {
    private struct Payload: Decodable {
        let userState: String
        let userIntent: String
        let responseMode: String
        let shouldInterrupt: Bool
        let confidence: String
        let reason: String

        private enum CodingKeys: String, CodingKey {
            case userState = "user_state"
            case userIntent = "user_intent"
            case responseMode = "response_mode"
            case shouldInterrupt = "should_interrupt"
            case confidence
            case reason
        }
    }

    static func parse(_ rawText: String) throws -> SidekickViewModel.AgentDecision {
        let cleaned = extractJSONObject(from: rawText)
        let data = Data(cleaned.utf8)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return SidekickViewModel.AgentDecision(
            userState: payload.userState,
            userIntent: payload.userIntent,
            responseMode: payload.responseMode,
            shouldInterrupt: payload.shouldInterrupt,
            confidence: payload.confidence,
            reason: payload.reason
        )
    }

    private static func extractJSONObject(from rawText: String) -> String {
        if let start = rawText.firstIndex(of: "{"), let end = rawText.lastIndex(of: "}") {
            return String(rawText[start...end])
        }
        return rawText
    }
}
