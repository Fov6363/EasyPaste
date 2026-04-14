import AppKit
import Carbon
import Combine
import Foundation
import OSLog

final class AppCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.yy.EasyPaste", category: "AutoPaste")

    @Published private(set) var shortcut: ShortcutConfiguration
    @Published private(set) var isAccessibilityTrusted: Bool

    let store: ClipboardStore
    let panelState = PanelState()

    private let shortcutStorageKey = "easyPaste.shortcutConfiguration"
    private var panelController: PanelController? = nil
    private var hotKeyManager: HotKeyManager? = nil
    private var workspaceObserver: NSObjectProtocol?
    private var previousFrontmostApplication: NSRunningApplication?
    private var pendingPasteProcessIdentifier: pid_t?
    private var hasPromptedForAccessibility = false

    init(store: ClipboardStore) {
        let shortcut = Self.loadShortcutConfiguration(forKey: "easyPaste.shortcutConfiguration")

        self.store = store
        self.shortcut = shortcut
        self.isAccessibilityTrusted = CGPreflightPostEventAccess()

        self.panelController = PanelController(
            rootView: ContentView(
                store: store,
                panelState: panelState,
                coordinator: self,
                onSelect: { [weak self] item in
                    self?.handleSelection(item)
                },
                onClose: { [weak self] in
                    self?.hidePanel()
                }
            )
        )

        self.hotKeyManager = HotKeyManager(configuration: shortcut) { [weak self] in
            self?.togglePanel()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWorkspaceActivation(notification)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    var shortcutDisplayText: String {
        shortcut.displayText
    }

    var shortcutMenuLabel: String {
        shortcut.menuLabel
    }

    func togglePanel() {
        guard let panelController else { return }

        if panelController.isVisible {
            hidePanel()
            return
        }

        showPanel()
    }

    func showPanel() {
        refreshAccessibilityStatus()
        captureFrontmostApplication()
        panelController?.show()

        DispatchQueue.main.async { [weak self] in
            self?.panelState.prepareForPresentation()
        }
    }

    func hidePanel() {
        panelController?.hide()
    }

    func updateShortcut(_ configuration: ShortcutConfiguration) {
        guard shortcut != configuration else { return }

        shortcut = configuration
        saveShortcutConfiguration(configuration, forKey: shortcutStorageKey)
        hotKeyManager?.update(configuration: configuration)
        objectWillChange.send()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = CGPreflightPostEventAccess()
    }

    func requestAccessibilityPermission() {
        refreshAccessibilityStatus()

        guard !isAccessibilityTrusted else { return }

        hasPromptedForAccessibility = true
        CGRequestPostEventAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshAccessibilityStatus()
        }
    }

    private func handleSelection(_ item: ClipboardItem) {
        logger.notice("selection received textLength=\(item.text.count, privacy: .public)")
        store.copyHistoryItem(item)
        hidePanel()
        restorePreviousApplicationAndPaste()
    }

    private func captureFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            logger.notice("capture skipped because current frontmost is EasyPaste or nil")
            return
        }

        previousFrontmostApplication = app
        logger.notice("captured frontmost app name=\(app.localizedName ?? "unknown", privacy: .public) pid=\(app.processIdentifier, privacy: .public)")
    }

    private func restorePreviousApplicationAndPaste() {
        guard let app = previousFrontmostApplication else {
            logger.error("restore skipped because previous frontmost application is unavailable")
            return
        }

        pendingPasteProcessIdentifier = app.processIdentifier
        logger.notice("restoring app name=\(app.localizedName ?? "unknown", privacy: .public) pid=\(app.processIdentifier, privacy: .public)")

        NSApplication.shared.hide(nil)
        app.unhide()
        app.activate(options: [.activateAllWindows])
        schedulePaste(for: app, attempt: 0)
    }

    private func schedulePaste(for app: NSRunningApplication, attempt: Int) {
        let delay = attempt == 0 ? 0.22 : 0.12

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }

            let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let didActivateTarget = frontmostProcessIdentifier == app.processIdentifier
            self.logger.notice("paste attempt=\(attempt, privacy: .public) targetPid=\(app.processIdentifier, privacy: .public) frontmostPid=\(frontmostProcessIdentifier ?? -1, privacy: .public)")

            if didActivateTarget, self.triggerPasteShortcutIfPossible(target: app) {
                return
            }

            guard attempt < 4 else {
                _ = self.triggerPasteShortcutIfPossible(target: app)
                return
            }

            app.activate(options: [.activateAllWindows])
            self.schedulePaste(for: app, attempt: attempt + 1)
        }
    }

    @discardableResult
    private func triggerPasteShortcutIfPossible(target: NSRunningApplication?) -> Bool {
        refreshAccessibilityStatus()

        guard ensureAccessibilityPermissionIfNeeded() else {
            logger.error("paste skipped because accessibility permission is missing")
            return false
        }

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            logger.error("paste event creation failed trusted=\(self.isAccessibilityTrusted, privacy: .public)")
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        logger.notice("posting cmd+v targetPid=\(target?.processIdentifier ?? -1, privacy: .public) frontmostPid=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1, privacy: .public)")
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        if pendingPasteProcessIdentifier == target?.processIdentifier {
            pendingPasteProcessIdentifier = nil
        }
        return true
    }

    private func ensureAccessibilityPermissionIfNeeded() -> Bool {
        if isAccessibilityTrusted {
            return true
        }

        if !hasPromptedForAccessibility {
            requestAccessibilityPermission()
        }

        return false
    }

    @objc
    private func applicationDidBecomeActive() {
        refreshAccessibilityStatus()
    }

    private func handleWorkspaceActivation(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        logger.notice("workspace activated name=\(application.localizedName ?? "unknown", privacy: .public) pid=\(application.processIdentifier, privacy: .public)")

        guard let pendingPasteProcessIdentifier,
              pendingPasteProcessIdentifier == application.processIdentifier else {
            return
        }

        self.logger.notice("activation observer confirmed target pid=\(application.processIdentifier, privacy: .public)")
    }

    private func saveShortcutConfiguration(_ configuration: ShortcutConfiguration, forKey key: String) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadShortcutConfiguration(forKey key: String) -> ShortcutConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key),
              let configuration = try? JSONDecoder().decode(ShortcutConfiguration.self, from: data) else {
            return .defaultValue
        }

        return configuration
    }
}

final class PanelState: ObservableObject {
    @Published private(set) var focusToken = UUID()

    func prepareForPresentation() {
        focusToken = UUID()
    }
}
