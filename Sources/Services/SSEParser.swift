import Foundation

enum SSEParser {
    struct SSEError: Sendable {
        let message: String
        let type: String?
    }

    /// Returns a StreamDelta if the line contains a valid data event, nil otherwise.
    static func parse(line: String) -> StreamDelta? {
        guard let jsonString = extractJSON(from: line) else { return nil }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Must have "choices" key (not an error response)
        guard let choices = json["choices"] as? [[String: Any]],
              !choices.isEmpty
        else { return nil }

        let first = choices[0]
        let delta = first["delta"] as? [String: Any]

        let text: String?
        if let content = delta?["content"] {
            text = content as? String  // nil if content is NSNull
        } else {
            text = nil
        }

        let finishReason: String?
        if let fr = first["finish_reason"], !(fr is NSNull) {
            finishReason = fr as? String
        } else {
            finishReason = nil
        }

        return StreamDelta(text: text, finishReason: finishReason)
    }

    /// Returns an SSEError if the line contains an error payload, nil otherwise.
    static func parseError(line: String) -> SSEError? {
        guard let jsonString = extractJSON(from: line) else { return nil }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorObj = json["error"] as? [String: Any],
              let message = errorObj["message"] as? String
        else { return nil }

        let type = errorObj["type"] as? String
        return SSEError(message: message, type: type)
    }

    // MARK: - Private helpers

    /// Strips the "data:" prefix and optional single space, returns the remainder.
    /// Returns nil for [DONE], non-data lines, empty/whitespace lines, etc.
    private static func extractJSON(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.hasPrefix("data:") else { return nil }

        // Everything after "data:"
        let afterPrefix = String(trimmed.dropFirst(5))

        // Strip at most one leading space (SSE spec)
        let payload: String
        if afterPrefix.hasPrefix(" ") {
            payload = String(afterPrefix.dropFirst(1))
        } else {
            payload = afterPrefix
        }

        guard payload != "[DONE]" else { return nil }
        return payload
    }
}
