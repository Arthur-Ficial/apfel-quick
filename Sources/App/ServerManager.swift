import Foundation
import os
import ApfelServerKit

/// Manages the apfel HTTP server process for apfel-quick.
///
/// Implementation delegates to `ApfelServerKit.ApfelServer`; this class exists
/// to preserve the existing `@MainActor` call-site semantics for AppDelegate
/// and to wrap state changes in a SwiftUI-friendly enum.
@MainActor
final class ServerManager {
    enum State {
        case idle
        case starting
        case running(port: Int, process: Process?)
        case failed(String)
    }

    private(set) var state: State = .idle
    private let backing: ApfelServer

    init() {
        self.backing = ApfelServer()
    }

    // MARK: - Static helpers kept for call-site and test compatibility

    nonisolated static func findBinary(named name: String) -> String? {
        ApfelBinaryFinder.find(name: name)
    }

    nonisolated static func findApfelBinary() -> String? {
        ApfelBinaryFinder.find(name: "apfel")
    }

    nonisolated static func isPortAvailable(_ port: Int) -> Bool {
        PortScanner.isAvailable(port)
    }

    nonisolated static func findAvailablePort(startingAt: Int = 11450) -> Int {
        PortScanner.firstAvailable(in: startingAt...(startingAt + 9)) ?? startingAt
    }

    nonisolated static func buildArguments(port: Int) -> [String] {
        ["--serve", "--port", "\(port)", "--cors", "--permissive"]
    }

    // MARK: - Lifecycle

    func start() async -> Int? {
        state = .starting
        do {
            let port = try await backing.start()
            let isManaged = await backing.isManaged
            if isManaged {
                printToStderr("apfel-quick: server ready on port \(port)")
            } else {
                printToStderr("apfel-quick: connected to existing server on port \(port)")
            }
            state = .running(port: port, process: nil)
            return port
        } catch let error as ApfelServerError {
            let message: String
            switch error {
            case .binaryNotFound:
                message = "apfel not found. Install: brew install Arthur-Ficial/tap/apfel"
                printToStderr("apfel-quick: error: apfel not found in PATH")
            case .noPortAvailable:
                message = "No free port in the apfel-quick range (11450-11459)."
            case .spawnFailed(let underlying):
                message = "Failed to start apfel: \(underlying)"
            case .healthCheckTimeout:
                message = "Server failed to start within 8 seconds"
            }
            state = .failed(message)
            return nil
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func stop() {
        Task { await backing.stop() }
        state = .idle
        printToStderr("apfel-quick: server terminated")
    }
}

// MARK: - Logging helpers (unchanged from pre-migration)

private let appLogger = Logger(subsystem: "com.fullstackoptimization.apfel-quick", category: "general")

func printToStderr(_ message: String) {
    if isRunningAsAppBundle() {
        appLogger.info("\(message)")
    } else {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

func isRunningAsAppBundle() -> Bool {
    let path = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
    return path.contains(".app/Contents/MacOS/")
}
