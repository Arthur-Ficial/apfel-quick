import Foundation

protocol QuickService: Sendable {
    func send(prompt: String) -> AsyncThrowingStream<StreamDelta, Error>
    func healthCheck() async throws -> Bool
}
