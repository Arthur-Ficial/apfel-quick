import Foundation
import AppKit
import Observation

@Observable @MainActor final class QuickViewModel {

    // MARK: - Published state

    var input: String = ""
    var output: String = ""
    var isStreaming: Bool = false
    var errorMessage: String? = nil
    var settings: QuickSettings
    var updateState: UpdateState = .idle

    // MARK: - Dependencies

    var service: (any QuickService)?

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

    func submit() async {
        guard !input.isEmpty else { return }
        guard let service else {
            errorMessage = "Not connected to any service."
            return
        }

        // Clear state before starting
        errorMessage = nil
        output = ""
        isStreaming = true

        let stream = service.send(prompt: input)

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

    // MARK: - Clear

    func clearOutput() {
        output = ""
        errorMessage = nil
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
