import AppKit
import SwiftUI

/// Owns the status item: left-click toggles, right-click or ⌃-click opens the menu.
///
/// The icon only ever reflects the saved state (see `HardlockModel`): it changes
/// after the agent's registration is confirmed, and stays put if that fails.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: HardlockModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let iconModel = StatusIconModel()
    private let iconOverlay: PassthroughHostingView<StatusIconView>

    private let menu = NSMenu()
    private let toggleMenuItem = NSMenuItem()
    private let statusMenuItem = NSMenuItem()

    private var settleTask: Task<Void, Never>?

    init(model: HardlockModel) {
        self.model = model
        iconOverlay = PassthroughHostingView(rootView: StatusIconView(model: iconModel))
        super.init()

        configureButton()
        configureMenu()
        render(animated: false)

        model.onEnabledChange = { [weak self] animated in
            self?.enabledChanged(animated: animated)
        }
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        iconOverlay.sizingOptions = []
        iconOverlay.frame = button.bounds
        iconOverlay.autoresizingMask = [.width, .height]
        button.addSubview(iconOverlay)
    }

    private func configureMenu() {
        menu.autoenablesItems = false
        menu.font = .menuFont(ofSize: 13)
        menu.minimumWidth = 210
        menu.delegate = self

        toggleMenuItem.target = self
        toggleMenuItem.action = #selector(toggleFromMenu)

        statusMenuItem.isEnabled = false

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit Hardlock",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp

        menu.addItem(toggleMenuItem)
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)
    }

    // MARK: - Interaction

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        model.refresh()
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            model.toggle()
        }
    }

    @objc private func toggleFromMenu(_ sender: NSMenuItem) {
        model.toggle()
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        showSettings()
    }

    private func showMenu() {
        updateMenuItems()
        // Attaching the menu only while it's open keeps left-click free for toggling.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    /// Opens SwiftUI's Settings window by invoking the app menu's own "Settings…"
    /// item. Calling `showSettingsWindow:` directly is unsupported since macOS 14.
    private func showSettings() {
        NSApp.activate()
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu,
              let index = appMenu.items.firstIndex(where: { $0.keyEquivalent == "," })
        else { return }
        appMenu.performActionForItem(at: index)
    }

    // MARK: - Rendering

    private func enabledChanged(animated: Bool) {
        render(animated: animated)
        if animated {
            AccessibilityNotification.Announcement(model.isEnabled ? "Hardlock enabled" : "Hardlock disabled").post()
        }
    }

    private func updateMenuItems() {
        toggleMenuItem.title = model.isEnabled ? "Disable Lock After Login" : "Enable Lock After Login"
        toggleMenuItem.isEnabled = !model.isBusy

        let status = model.needsApproval ? "Needs Approval" : model.isEnabled ? "Enabled" : "Disabled"
        statusMenuItem.attributedTitle = NSAttributedString(
            string: "Status: \(status)",
            attributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
    }

    private func render(animated: Bool) {
        guard let button = statusItem.button else { return }
        let isEnabled = model.isEnabled
        button.setAccessibilityLabel(isEnabled ? "Hardlock, enabled" : "Hardlock, disabled")
        settleTask?.cancel()

        guard animated else {
            iconModel.isAnimating = false
            iconModel.isEnabled = isEnabled
            button.image = StatusIcon.image(enabled: isEnabled)
            return
        }

        // Hand the glyph to SwiftUI for the symbol transition, then back to the
        // template image once it settles so macOS tints it like any other item.
        button.image = nil
        iconModel.isAnimating = true
        withAnimation {
            iconModel.isEnabled = isEnabled
        }
        if isEnabled {
            iconModel.bounceCount += 1
        }

        settleTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            render(animated: false)
        }
    }
}
