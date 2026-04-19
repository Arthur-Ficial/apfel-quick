import AppKit
import SwiftUI

// Borderless panel that can still become key — needed so the TextField
// receives keyboard input. Without the override, a .borderless style mask
// prevents the panel from ever becoming the key window.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var viewModel: QuickViewModel?
    private var panel: NSPanel?
    private var welcomePanel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var mouseMonitor: Any?
    private var statusItem: NSStatusItem?

    private let serverManager = ServerManager()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vm = QuickViewModel(currentVersion: Bundle.main.shortVersion)
        self.viewModel = vm

        Task { @MainActor [weak self] in
            await self?.bootstrap(viewModel: vm)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor  { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseMonitor  { NSEvent.removeMonitor(monitor) }
        serverManager.stop()
    }

    // MARK: - Bootstrap

    private func bootstrap(viewModel: QuickViewModel) async {
        // a. Load settings from UserDefaults
        let settings = QuickSettings.load()
        viewModel.settings = settings

        // b. Create NSPanel with OverlayView hosted in NSHostingController
        let panel = makePanel(viewModel: viewModel)
        self.panel = panel

        // c. Register global hotkey (Ctrl+Space)
        registerGlobalHotkey()

        // d. Register local mouse monitor for click-outside dismissal
        registerMouseDismissMonitor()

        // e. Setup status bar item if settings.showMenuBar
        if settings.showMenuBar {
            setupStatusItem()
        }

        // Listen for Escape / dismiss notifications from OverlayView
        NotificationCenter.default.addObserver(
            forName: .dismissOverlay,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hideOverlay() }
        }

        // Re-register hotkey when settings change
        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reregisterGlobalHotkey() }
        }

        // Panel auto-resize: observe viewModel state and grow/shrink the panel
        // to fit the current overlay content.
        startPanelSizeObserver(viewModel: viewModel)

        // f. Show WelcomeOverlayView FIRST — before we block on server start
        //    so the user sees UI immediately on first run.
        if !settings.hasSeenWelcome {
            showWelcomePanel()
        } else if !settings.launchAtLoginPromptShown {
            // Welcome already seen on a prior launch but login prompt never shown
            // (upgrade path) — show it now.
            promptForLaunchAtLogin(viewModel: viewModel)
        }

        // g. Start ServerManager in parallel — do NOT await here so the UI
        //    stays responsive. When the server is ready we inject the service.
        Task { [weak self, weak viewModel] in
            guard let self, let viewModel else { return }
            if let port = await self.serverManager.start() {
                await MainActor.run {
                    viewModel.service = ApfelQuickService(port: port)
                }
            }
        }

        // h. Check for update silently if enabled
        if settings.checkForUpdatesOnLaunch {
            Task { await viewModel.checkForUpdateSilently() }
        }
    }

    // MARK: - Panel construction

    private func makePanel(viewModel: QuickViewModel) -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 60),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(NSWindow.Level.floating.rawValue) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false   // keep visible across app focus changes
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.worksWhenModal = true

        let hostingController = NSHostingController(
            rootView: OverlayView(viewModel: viewModel)
                .frame(width: 620)
        )
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 620, height: 60)
        panel.contentViewController = hostingController

        // Center on active screen, upper third, after sizing
        if let screen = NSScreen.main {
            let width: CGFloat = 620
            let x = screen.frame.midX - width / 2
            let y = screen.frame.maxY - screen.frame.height * 0.35
            panel.setFrame(NSRect(x: x, y: y, width: width, height: 60), display: false)
        }

        return panel
    }

    // MARK: - Show / Hide / Toggle

    func showOverlay() {
        guard let panel else { return }
        // Re-center on the screen that currently has the mouse cursor
        if let screen = NSScreen.main {
            let width: CGFloat = 620
            let x = screen.frame.midX - width / 2
            let y = screen.frame.maxY - screen.frame.height * 0.35
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hideOverlay() {
        guard let panel else { return }
        panel.orderOut(nil)
        viewModel?.input = ""
        viewModel?.clearOutput()
    }

    func toggleOverlay() {
        guard let panel else { return }
        if panel.isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    // MARK: - Global hotkey (configurable, default Option+Space)

    private func registerGlobalHotkey() {
        guard let vm = viewModel else { return }
        let keyCode = vm.settings.hotkeyKeyCode
        let modifierFlags = NSEvent.ModifierFlags(rawValue: vm.settings.hotkeyModifiers)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifierFlags,
                  event.keyCode == keyCode else { return }
            Task { @MainActor [weak self] in self?.toggleOverlay() }
        }
    }

    func reregisterGlobalHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        registerGlobalHotkey()
    }

    // MARK: - Click-outside dismissal

    private func registerMouseDismissMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                let clickPoint = event.locationInWindow
                let screenPoint: NSPoint
                if let window = event.window {
                    screenPoint = window.convertPoint(toScreen: clickPoint)
                } else {
                    screenPoint = clickPoint
                }
                // Ignore clicks in the menu bar region (status item clicks are
                // handled separately by handleStatusItemClick)
                if let screen = NSScreen.main {
                    let menuBarHeight: CGFloat = 30
                    let menuBarTop = screen.frame.maxY
                    if screenPoint.y >= menuBarTop - menuBarHeight {
                        return
                    }
                }
                if !panel.frame.contains(screenPoint) {
                    self.hideOverlay()
                }
            }
        }
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "bolt.fill",
                accessibilityDescription: "apfel-quick"
            )
            button.imagePosition = .imageOnly
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            toggleOverlay()
            return
        }
        if event.type == .rightMouseUp {
            let menu = buildContextMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        } else {
            toggleOverlay()
        }
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let show = NSMenuItem(
            title: "Open apfel-quick",
            action: #selector(showOverlayFromMenu),
            keyEquivalent: " "
        )
        show.keyEquivalentModifierMask = .control
        show.target = self
        menu.addItem(show)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let welcome = NSMenuItem(
            title: "Show Welcome Again",
            action: #selector(showWelcomeFromMenu),
            keyEquivalent: ""
        )
        welcome.target = self
        menu.addItem(welcome)

        menu.addItem(.separator())

        let version = NSMenuItem(
            title: "apfel-quick v\(Bundle.main.shortVersion)",
            action: nil,
            keyEquivalent: ""
        )
        version.isEnabled = false
        menu.addItem(version)

        let website = NSMenuItem(
            title: "Visit apfel-quick.franzai.com",
            action: #selector(openWebsite),
            keyEquivalent: ""
        )
        website.target = self
        menu.addItem(website)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit apfel-quick",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    // MARK: - Panel auto-resize observer

    private func startPanelSizeObserver(viewModel: QuickViewModel) {
        // Simple polling loop — cheap and avoids @Sendable closure issues.
        Task { @MainActor [weak self, weak viewModel] in
            while let _ = self, let _ = viewModel {
                self?.resizePanelForContent()
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func resizePanelForContent() {
        guard let panel, let vm = viewModel else { return }
        let inputHeight: CGFloat = 60
        var total = inputHeight
        if !vm.output.isEmpty || vm.isStreaming {
            // Measure approximately: 20pt per line, estimate line count from characters
            let maxBodyHeight: CGFloat = 380
            let approxLines = max(1, vm.output.count / 60 + 1)
            let bodyHeight = min(maxBodyHeight, CGFloat(approxLines) * 22 + 40)
            total += bodyHeight
        }
        if vm.errorMessage != nil {
            total += 40
        }
        var frame = panel.frame
        if abs(frame.height - total) > 1 {
            let delta = total - frame.height
            frame.size.height = total
            frame.origin.y -= delta  // grow down from the top
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    @objc private func showOverlayFromMenu() {
        showOverlay()
    }

    @objc private func openSettingsFromMenu() {
        showOverlay()
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func showWelcomeFromMenu() {
        welcomePanel?.orderOut(nil)
        welcomePanel = nil
        showWelcomePanel()
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://apfel-quick.franzai.com") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Welcome panel

    func showWelcomePanel() {
        guard let vm = viewModel else { return }
        let welcomePanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        welcomePanel.title = "Welcome"
        welcomePanel.level = NSWindow.Level(rawValue: Int(NSWindow.Level.floating.rawValue) + 2)
        welcomePanel.isReleasedWhenClosed = false
        welcomePanel.center()

        let hostingController = NSHostingController(
            rootView: WelcomeOverlayView(viewModel: vm, onContinue: { [weak self, weak welcomePanel] in
                Task { @MainActor [weak self, weak welcomePanel] in
                    guard let self else { return }
                    self.viewModel?.settings.hasSeenWelcome = true
                    self.viewModel?.settings.save()
                    welcomePanel?.orderOut(nil)
                    self.welcomePanel = nil
                    // Follow up with the launch-at-login dialog, then show overlay
                    if let vm = self.viewModel, !vm.settings.launchAtLoginPromptShown {
                        self.promptForLaunchAtLogin(viewModel: vm)
                    }
                    self.showOverlay()
                }
            })
        )
        welcomePanel.contentViewController = hostingController
        self.welcomePanel = welcomePanel
        welcomePanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Mirror of apfel-clip's launch-at-login alert — asked once, persisted.
    @MainActor
    private func promptForLaunchAtLogin(viewModel: QuickViewModel) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Start apfel-quick at login?"
        alert.informativeText = "Keep apfel-quick ready in your menu bar every time you sign in. You can change this later in Settings."
        alert.addButton(withTitle: "Enable at Login")
        alert.addButton(withTitle: "Not Now")
        let enable = alert.runModal() == .alertFirstButtonReturn
        viewModel.settings.launchAtLogin = enable
        viewModel.settings.launchAtLoginPromptShown = true
        viewModel.settings.save()
        viewModel.applyLaunchAtLogin()
    }
}

// MARK: - QuickViewModel extensions

extension QuickViewModel {

    // MARK: Silent update check

    /// Fetches latest release tag from GitHub and calls handleUpdateCheck.
    /// Never surfaces errors to the user.
    func checkForUpdateSilently() async {
        guard let url = URL(string: "https://api.github.com/repos/Arthur-Ficial/apfel-quick/releases/latest") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                await handleUpdateCheck(remoteVersion: tag)
            }
        } catch {
            // Silent — ignore network errors
        }
    }

}
