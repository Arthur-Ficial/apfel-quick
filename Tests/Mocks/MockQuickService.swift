import Foundation
@testable import apfel_quick

actor MockQuickService: QuickService {
    var responses: [StreamDelta] = []
    var shouldThrow: Bool = false
    var delay: Duration = .zero
    var sendCallCount: Int = 0
    var lastPrompt: String?

    func send(prompt: String) -> AsyncThrowingStream<StreamDelta, Error> {
        sendCallCount += 1
        lastPrompt = prompt
        let responses = responses
        let shouldThrow = shouldThrow
        let delay = delay
        return AsyncThrowingStream { continuation in
            Task {
                if shouldThrow {
                    continuation.finish(throwing: MockError.intentional)
                    return
                }
                for delta in responses {
                    if delay != .zero {
                        try? await Task.sleep(for: delay)
                    }
                    continuation.yield(delta)
                }
                continuation.finish()
            }
        }
    }

    func healthCheck() async throws -> Bool { true }

    enum MockError: Error {
        case intentional
    }
}
