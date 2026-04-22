import Foundation
import ApfelServerKit

struct ApfelQuickService: QuickService, @unchecked Sendable {
    let baseURL: URL
    let modelName: String

    /// System prompt that keeps answers tight: no preamble, no postamble,
    /// no "as an AI" disclaimers, no apologies. Just the answer the user wants.
    static let systemPrompt: String = """
    You are a fast, direct assistant in a Spotlight-style overlay. \
    Answer only what is asked. No preamble, no postamble, no apologies, \
    no "as an AI" disclaimers, no safety moralizing, no invitations to ask \
    follow-ups. If the user asks a factual question, state the fact. If \
    they ask for code, give code. If they ask for a translation, give only \
    the translation. Be concise and direct.
    """

    init(baseURL: URL, modelName: String = "apple-foundationmodel") {
        self.baseURL = baseURL
        self.modelName = modelName
    }

    init(port: Int, modelName: String = "apple-foundationmodel") {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
        self.modelName = modelName
    }

    /// Build the wire-format URLRequest that streams a chat completion.
    /// Preserved as a public helper so wire-format tests can inspect it;
    /// the actual streaming uses `ApfelClient.chatCompletions(_:)` below.
    func buildRequest(prompt: String) throws -> URLRequest {
        let url = URL(string: "/v1/chat/completions", relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": modelName,
            "stream": true,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": prompt],
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func send(prompt: String) -> AsyncThrowingStream<StreamDelta, Error> {
        let port = baseURL.port ?? 11450
        let host = baseURL.host ?? "127.0.0.1"
        let client = ApfelClient(port: port, host: host)
        let request = ChatRequest(
            model: modelName,
            messages: [
                ChatMessage(role: "system", content: Self.systemPrompt),
                ChatMessage(role: "user", content: prompt),
            ],
            stream: true
        )
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await delta in client.chatCompletions(request) {
                        continuation.yield(
                            StreamDelta(text: delta.text, finishReason: delta.finishReason)
                        )
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as ApfelClientError {
                    switch error {
                    case .httpStatus(let code):
                        continuation.finish(
                            throwing: QuickServiceError.serverError("HTTP \(code)")
                        )
                    case .stream(let message):
                        continuation.finish(
                            throwing: QuickServiceError.streamError(message)
                        )
                    case .invalidURL:
                        continuation.finish(
                            throwing: QuickServiceError.connectionFailed(
                                "Could not build request URL from host/port"
                            )
                        )
                    }
                } catch {
                    continuation.finish(
                        throwing: QuickServiceError.connectionFailed(
                            "Connection failed: \(error.localizedDescription)"
                        )
                    )
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func healthCheck() async throws -> Bool {
        let url = URL(string: "/health", relativeTo: baseURL)!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            return false
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["modelAvailable"] as? Bool) == true
    }
}

enum QuickServiceError: Error {
    case serverError(String)
    case streamError(String)
    case connectionFailed(String)
}
