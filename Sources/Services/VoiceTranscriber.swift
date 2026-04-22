import Foundation
import ApfelServerKit

/// Typed errors surfaced by the ohr-based voice transcriber.
enum VoiceTranscriberError: Error, Equatable, Sendable {
    case binaryNotFound
    case spawnFailed(String)
}

/// Wraps an `ohr --listen` subprocess and exposes its stdout lines as
/// an `AsyncStream<String>`. Actor-isolated for safe start/stop from
/// the main view model and from test code alike.
actor VoiceTranscriber {

    private let binaryFinder: @Sendable () -> String?
    private let extraArgs: [String]
    private var process: Process?
    private var stdoutReader: Task<Void, Never>?
    private var continuation: AsyncStream<String>.Continuation?
    private let stream: AsyncStream<String>

    /// Whether a subprocess is currently running.
    var isRunning: Bool { process?.isRunning ?? false }

    /// Stream of stdout lines the transcriber has emitted so far, plus
    /// lines it emits in the future until `stop()` is called or the
    /// process exits on its own.
    var lines: AsyncStream<String> { stream }

    init(
        binaryFinder: @Sendable @escaping () -> String? = { ApfelBinaryFinder.find(name: "ohr") },
        extraArgs: [String] = ["--listen", "--quiet"]
    ) {
        self.binaryFinder = binaryFinder
        self.extraArgs = extraArgs
        var cont: AsyncStream<String>.Continuation!
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Spawn `ohr` with the configured arguments. Throws on missing binary
    /// or spawn failure.
    func start() async throws {
        guard let binary = binaryFinder() else {
            throw VoiceTranscriberError.binaryNotFound
        }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = extraArgs
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw VoiceTranscriberError.spawnFailed(error.localizedDescription)
        }
        self.process = process

        let continuation = self.continuation
        stdoutReader = Task.detached(priority: .userInitiated) {
            let handle = pipe.fileHandleForReading
            var buffer = Data()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let lineBytes = buffer.subdata(in: 0..<newline)
                    let line = String(data: lineBytes, encoding: .utf8) ?? ""
                    buffer.removeSubrange(0...newline)
                    if !line.isEmpty { continuation?.yield(line) }
                }
            }
            // Flush any trailing partial line.
            if !buffer.isEmpty, let tail = String(data: buffer, encoding: .utf8), !tail.isEmpty {
                continuation?.yield(tail)
            }
        }
    }

    /// Terminate the subprocess. Safe to call multiple times; no-op when
    /// nothing is running.
    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdoutReader?.cancel()
        stdoutReader = nil
    }
}
