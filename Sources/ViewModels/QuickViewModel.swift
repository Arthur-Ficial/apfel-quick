import Foundation
import AppKit
import Observation
import ApfelServerKit

@Observable @MainActor final class QuickViewModel {

    // MARK: - Published state

    var input: String = ""
    var output: String = ""
    var isStreaming: Bool = false
    var isRecording: Bool = false
    var errorMessage: String? = nil
    var settings: QuickSettings
    var updateState: UpdateState = .idle
    /// True briefly after auto-copy fires, so the UI can flash a "Copied!" indicator.
    var justCopied: Bool = false

    @ObservationIgnored private var voiceTask: Task<Void, Never>?
    @ObservationIgnored private var voiceTranscriber: VoiceTranscriber?

    // MARK: - Dependencies

    var service: (any QuickService)?

    // How long submit() waits for `service` to be injected before giving up.
    // Exposed so tests can lower this to keep them fast.
    @ObservationIgnored var serviceWaitTimeout: Duration = .seconds(5)

    // How long the "just copied" flag stays true after auto-copy.
    @ObservationIgnored var justCopiedTimeout: Duration = .seconds(2)
    @ObservationIgnored private var justCopiedTask: Task<Void, Never>?

    // MARK: - Private

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored let currentVersion: String

    // MARK: - Init

    init(
        settings: QuickSettings = .load(),
        service: (any QuickService)? = nil,
        currentVersion: String = "1.0.0"
    ) {
        self.settings = settings
        self.service = service
        self.currentVersion = currentVersion
    }

    // MARK: - Submit

    /// Saved-prompt aliases matching the current `input`, sorted alphabetically.
    /// Empty whenever the input is not a prefix-based command.
    var savedPromptMatches: [SavedPrompt] {
        SavedPromptResolver.matches(
            input: input,
            prefix: settings.savedPromptPrefix,
            savedPrompts: settings.savedPrompts
        )
    }

    /// Replace `input` with `<prefix><alias> ` so the user can keep typing
    /// context after committing to a saved prompt.
    func complete(savedPrompt: SavedPrompt) {
        input = settings.savedPromptPrefix + savedPrompt.alias + " "
    }

    func submit() async {
        guard !input.isEmpty else { return }

        // Expand saved-prompt aliases before anything else. Non-matches
        // (including inputs that look like `/foo` but reference an unknown
        // alias) fall through to the regular path below.
        let resolved = SavedPromptResolver.resolve(
            input: input,
            prefix: settings.savedPromptPrefix,
            savedPrompts: settings.savedPrompts
        )
        let effectivePrompt = resolved ?? input

        // Math shortcut — evaluate locally without the AI
        if MathExpressionDetector.isMathExpression(effectivePrompt) {
            errorMessage = nil
            do {
                let result = try MathCalculator.evaluate(effectivePrompt)
                output = MathCalculator.format(result)
                if settings.autoCopy {
                    copyOutput()
                    markJustCopied()
                }
            } catch {
                errorMessage = "Math error: \(error)"
            }
            return
        }

        // Wait briefly for service to be injected if bootstrap is still running.
        errorMessage = nil
        output = ""
        isStreaming = true
        let waitingService = await waitForService(timeout: serviceWaitTimeout)
        guard let service = waitingService else {
            isStreaming = false
            errorMessage = "Still starting on-device AI — please try again in a moment."
            return
        }

        let stream = service.send(prompt: effectivePrompt)

        streamTask = Task {
            do {
                for try await delta in stream {
                    if Task.isCancelled { break }
                    if let text = delta.text {
                        output += text
                    }
                }
                // Stream completed normally
                isStreaming = false
                if settings.autoCopy && !output.isEmpty {
                    copyOutput()
                    markJustCopied()
                }
            } catch is CancellationError {
                // Cancelled — do not set errorMessage
                isStreaming = false
                output = ""
            } catch {
                errorMessage = error.localizedDescription
                isStreaming = false
            }
        }

        await streamTask?.value
    }

    // MARK: - Wait for service injection (poll until non-nil or timeout)

    private func waitForService(timeout: Duration) async -> (any QuickService)? {
        if let service { return service }
        let deadline = ContinuousClock.now.advanced(by: timeout)
        let pollInterval: Duration = .milliseconds(50)
        while ContinuousClock.now < deadline {
            if let service { return service }
            try? await Task.sleep(for: pollInterval)
        }
        return service
    }

    // MARK: - Voice (ohr)

    /// Start or stop ohr-backed voice transcription. Toggles `isRecording`.
    func toggleVoice() async {
        if isRecording {
            await stopVoice()
        } else {
            await startVoice()
        }
    }

    private func startVoice() async {
        guard !isRecording else { return }
        let pathOverride = settings.ohrBinaryPathOverride
        let transcriber = VoiceTranscriber(
            binaryFinder: {
                if let pathOverride, !pathOverride.isEmpty { return pathOverride }
                return AppBundledBinaryFinder.find(name: "ohr")
            },
            language: settings.voiceLanguage
        )
        do {
            try await transcriber.start()
        } catch VoiceTranscriberError.binaryNotFound {
            errorMessage = "ohr not found. Install: brew install Arthur-Ficial/tap/ohr"
            return
        } catch VoiceTranscriberError.microphoneDenied {
            errorMessage = "Microphone access denied. Enable apfel-quick in System Settings → Privacy & Security → Microphone."
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            return
        } catch VoiceTranscriberError.microphoneRestricted {
            errorMessage = "Microphone access restricted by system policy."
            return
        } catch {
            errorMessage = "Voice start failed: \(error.localizedDescription)"
            return
        }
        voiceTranscriber = transcriber
        isRecording = true
        errorMessage = nil
        voiceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let base = self.input
            var transcribed = ""
            for await segment in await transcriber.segments {
                if Task.isCancelled { break }
                transcribed += segment.text
                let trimmed = transcribed.trimmingCharacters(in: .whitespaces)
                self.input = base.isEmpty ? trimmed : base + " " + trimmed
            }
            self.isRecording = false
        }
    }

    private func stopVoice() async {
        await voiceTranscriber?.stop()
        voiceTranscriber = nil
        voiceTask?.cancel()
        voiceTask = nil
        isRecording = false
    }

    // MARK: - Cancel

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        output = ""
    }

    // MARK: - Copy

    func copyOutput() {
        guard !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    // MARK: - Just-copied flash

    func markJustCopied() {
        justCopiedTask?.cancel()
        justCopied = true
        justCopiedTask = Task { @MainActor [weak self, timeout = justCopiedTimeout] in
            try? await Task.sleep(for: timeout)
            self?.justCopied = false
        }
    }

    // MARK: - Clear

    func clearOutput() {
        output = ""
        errorMessage = nil
    }

    // MARK: - Launch at login

    func applyLaunchAtLogin() {
        let controller = SystemLaunchAtLoginController()
        try? controller.setEnabled(settings.launchAtLogin)
    }

    // MARK: - Install update

    func installUpdate() {
        guard case .updateAvailable(let version) = updateState else { return }
        updateState = .installing(newVersion: version)
        let isHB = FileManager.default.fileExists(atPath: "/opt/homebrew/Caskroom/apfel-quick")
        Task.detached { [weak self, version, isHB] in
            if isHB {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", "brew upgrade apfel-quick"]
                do {
                    try process.run()
                    process.waitUntilExit()
                    await MainActor.run { self?.updateState = .installed(newVersion: version) }
                } catch {
                    await MainActor.run { self?.updateState = .error(message: error.localizedDescription) }
                }
            } else {
                await MainActor.run {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Arthur-Ficial/apfel-quick/releases/latest")!)
                    self?.updateState = .idle
                }
            }
        }
    }

    // MARK: - Manual update check

    func checkForUpdateManual() async {
        updateState = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/Arthur-Ficial/apfel-quick/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                updateState = .error(message: "Could not parse release info")
                return
            }
            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            await handleUpdateCheck(remoteVersion: latestVersion)
        } catch {
            updateState = .error(message: error.localizedDescription)
        }
    }

    // MARK: - Update check

    func handleUpdateCheck(remoteVersion: String) async {
        if QuickViewModel.isVersionNewer(remoteVersion, than: currentVersion) {
            updateState = .updateAvailable(newVersion: remoteVersion)
        } else {
            updateState = .upToDate
        }
    }

    // MARK: - Version comparison

    nonisolated static func isVersionNewer(_ candidate: String, than current: String) -> Bool {
        let normalize: (String) -> [Int] = { version in
            let stripped = version.hasPrefix("v") ? String(version.dropFirst()) : version
            return stripped.split(separator: ".").compactMap { Int($0) }
        }

        var lhs = normalize(candidate)
        var rhs = normalize(current)

        // Pad shorter array with zeros
        let maxLen = max(lhs.count, rhs.count)
        while lhs.count < maxLen { lhs.append(0) }
        while rhs.count < maxLen { rhs.append(0) }

        for (l, r) in zip(lhs, rhs) {
            if l > r { return true }
            if l < r { return false }
        }
        return false // equal
    }
}
