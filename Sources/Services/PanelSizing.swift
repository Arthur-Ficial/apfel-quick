import CoreFoundation

/// Pure layout calculation for the apfel-quick overlay panel height.
/// Extracted from AppDelegate so it can be unit-tested without AppKit
/// and reused by the observation-driven resize path.
enum PanelSizing {

    static let inputHeight: CGFloat = 60
    static let maxBodyHeight: CGFloat = 380
    static let errorBannerHeight: CGFloat = 40

    static func panelHeight(output: String, isStreaming: Bool, errorMessage: String?) -> CGFloat {
        var total = inputHeight
        if !output.isEmpty || isStreaming {
            let approxLines = max(1, output.count / 60 + 1)
            let bodyHeight = min(maxBodyHeight, CGFloat(approxLines) * 22 + 40)
            total += bodyHeight
        }
        if errorMessage != nil {
            total += errorBannerHeight
        }
        return total
    }
}
