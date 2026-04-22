import Foundation
import AVFoundation

/// Microphone TCC status, mirrored from `AVCaptureDevice.authorizationStatus(for: .audio)`
/// so callers don't have to import AVFoundation.
enum MicrophoneAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted

    init(_ av: AVAuthorizationStatus) {
        switch av {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .denied
        }
    }
}

/// Protocol so tests can inject a deterministic implementation and skip the
/// real TCC prompt.
protocol MicrophonePermissionRequesting: Sendable {
    func currentStatus() -> MicrophoneAuthorizationStatus
    /// Returns the status after the request resolves. For `.notDetermined` this
    /// triggers the system TCC prompt; for any other state this is a no-op and
    /// returns the current state.
    func requestAccess() async -> MicrophoneAuthorizationStatus
}

/// Live implementation that talks to AVFoundation. Wrapping it in an actor-
/// neutral struct keeps the call site simple and the type `Sendable`.
///
/// Why this exists: ohr uses the microphone, but apfel-quick spawns ohr as a
/// subprocess. macOS TCC attributes the child's audio request to apfel-quick
/// (the responsible parent). If apfel-quick has never itself touched the
/// audio APIs, it has no TCC entry — the child's request is denied silently
/// and ohr exits. Calling `requestAccess` here surfaces the OS prompt against
/// apfel-quick's bundle ID (using `NSMicrophoneUsageDescription` from its
/// Info.plist). Once granted, the ohr child inherits permission.
struct SystemMicrophonePermission: MicrophonePermissionRequesting {
    func currentStatus() -> MicrophoneAuthorizationStatus {
        MicrophoneAuthorizationStatus(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func requestAccess() async -> MicrophoneAuthorizationStatus {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        if current != .notDetermined {
            return MicrophoneAuthorizationStatus(current)
        }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }
}
