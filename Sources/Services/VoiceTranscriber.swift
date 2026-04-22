import Foundation
import ApfelServerKit

/// Finds the ohr binary, preferring the copy bundled inside the app at
/// `Contents/Helpers/ohr` over anything on PATH. Bundling the helper inside
/// the app is what lets macOS TCC attribute the child process's microphone
/// request to apfel-quick's bundle ID — a system-installed /opt/homebrew/bin
/// binary is treated as a separate, unapproved process.
///
/// Search order:
///   1. `<app>/Contents/Helpers/<name>` (the canonical spot the build script
///      ships to)
///   2. `ApfelBinaryFinder.find(name:)` fallbacks (PATH, then /opt/homebrew,
///      /usr/local, etc.)
enum AppBundledBinaryFinder {
    static func find(name: String) -> String? {
        if let bundleExecutable = Bundle.main.executableURL {
            // Bundle.executableURL points at Contents/MacOS/<exe>. Helpers/ is
            // at Contents/Helpers/<name>, i.e. two directories up + "Helpers".
            let contents = bundleExecutable
                .deletingLastPathComponent()   // Contents/MacOS
                .deletingLastPathComponent()   // Contents
            let bundled = contents
                .appendingPathComponent("Helpers")
                .appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled.path
            }
        }
        return ApfelBinaryFinder.find(name: name)
    }
}

/// Typed errors surfaced by the ohr-based voice transcriber.
enum VoiceTranscriberError: Error, Equatable, Sendable {
    case binaryNotFound
    case spawnFailed(String)
    /// macOS TCC denied mic access to apfel-quick. Without this grant, the
    /// ohr subprocess's audio engine would fail silently. User must approve
    /// in System Settings → Privacy & Security → Microphone.
    case microphoneDenied
    case microphoneRestricted
}

/// A single transcription segment as emitted by `ohr --listen -o json`.
/// Matches ohr's `TranscriptionSegment` JSON shape: `{id, start, end, text}`.
struct VoiceSegment: Decodable, Equatable, Sendable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
}

/// Wraps an `ohr --listen -o json --language <code> --quiet` subprocess and
/// exposes its JSON segments as an `AsyncStream<VoiceSegment>`. Actor-
/// isolated for safe start/stop from the main view model and from tests.
///
/// Invocation rationale (learned the hard way):
/// - `--listen` gives live mic transcription.
/// - `-o json` keeps output machine-parseable AND satisfies ohr's rule that
///   `--listen` requires an "interactive terminal or non-plain output
///   format" (subprocess pipes don't count as TTY).
/// - `--language <code>` pins the locale. apfel-chat uses a similar
///   `languageCode` knob; we default to `en-US`.
/// - `--quiet` suppresses ohr's startup banner to stderr (we redirect stderr
///   to /dev/null anyway, but this is defensive).
///
/// Each stdout line is a compact JSON object that we decode into
/// `VoiceSegment` and yield on `segments`.
actor VoiceTranscriber {

    private let binaryFinder: @Sendable () -> String?
    private let language: String
    private let baseArgsOverride: [String]?
    private let micPermission: any MicrophonePermissionRequesting
    private var process: Process?
    private var stdoutReader: Task<Void, Never>?
    private var continuation: AsyncStream<VoiceSegment>.Continuation?
    private let stream: AsyncStream<VoiceSegment>

    /// Whether a subprocess is currently running.
    var isRunning: Bool { process?.isRunning ?? false }

    /// Stream of decoded segments. Consumers typically build the full
    /// transcript by appending `segment.text` as values arrive.
    var segments: AsyncStream<VoiceSegment> { stream }

    init(
        binaryFinder: @Sendable @escaping () -> String? = { AppBundledBinaryFinder.find(name: "ohr") },
        language: String = "en-US",
        baseArgsOverride: [String]? = nil,
        micPermission: any MicrophonePermissionRequesting = SystemMicrophonePermission()
    ) {
        self.binaryFinder = binaryFinder
        self.language = language
        self.baseArgsOverride = baseArgsOverride
        self.micPermission = micPermission
        var cont: AsyncStream<VoiceSegment>.Continuation!
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Spawn ohr with the right flags. Throws on missing binary, missing
    /// microphone permission, or spawn failure.
    func start() async throws {
        // Check mic permission BEFORE spawning ohr. apfel-quick never touches
        // AVAudioEngine itself, so without this call macOS TCC never prompts
        // for its bundle ID and the ohr child process is denied audio access
        // silently. Calling requestAccess surfaces the system dialog against
        // apfel-quick's Info.plist usage string; once granted, the ohr child
        // inherits access.
        let micStatus = await micPermission.requestAccess()
        switch micStatus {
        case .authorized:
            break
        case .denied:
            throw VoiceTranscriberError.microphoneDenied
        case .restricted:
            throw VoiceTranscriberError.microphoneRestricted
        case .notDetermined:
            // requestAccess is supposed to resolve this. If somehow it didn't,
            // treat as denied rather than spawning a doomed ohr.
            throw VoiceTranscriberError.microphoneDenied
        }
        guard let binary = binaryFinder() else {
            throw VoiceTranscriberError.binaryNotFound
        }
        let arguments = baseArgsOverride ?? [
            "--listen",
            "-o", "json",
            "--language", language,
            "--quiet",
        ]
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
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
            let decoder = JSONDecoder()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let lineBytes = buffer.subdata(in: 0..<newline)
                    buffer.removeSubrange(0...newline)
                    guard !lineBytes.isEmpty else { continue }
                    if let seg = try? decoder.decode(VoiceSegment.self, from: lineBytes) {
                        continuation?.yield(seg)
                    }
                }
            }
            if !buffer.isEmpty, let seg = try? decoder.decode(VoiceSegment.self, from: buffer) {
                continuation?.yield(seg)
            }
            // Reader hit EOF — ohr exited, its stdout pipe closed. Finish the
            // stream so any `for await seg in segments` consumers unblock.
            // Without this, the AsyncStream stays open forever waiting for
            // values that will never come, and test (and UI) iterators hang.
            continuation?.finish()
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
