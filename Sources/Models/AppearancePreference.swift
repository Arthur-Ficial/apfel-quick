import Foundation
import SwiftUI

/// User-selectable appearance for the overlay and settings window.
enum AppearancePreference: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark

    /// `nil` means "follow the system appearance"; SwiftUI interprets a nil
    /// `preferredColorScheme` as "do not override".
    var swiftUIColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "Follow system"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
