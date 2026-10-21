import AppKit
import Observation
import ServiceManagement

/// Shared state for the status item and the Settings window.
///
/// `isEnabled` only ever reflects the saved state: it changes after SMAppService
/// confirms the new registration, never optimistically.
@MainActor
@Observable
final class HardlockModel {
    private(set) var isEnabled = false
    private(set) var needsApproval = false
    private(set) var isBusy = false
    private(set) var launchAtLogin = false

    var delay: Int {
        didSet { UserDefaults.standard.set(delay, forKey: Preferences.delayKey) }
    }

    /// Called when `isEnabled` changes. `animated` is true for changes the user just made.
    @ObservationIgnored var onEnabledChange: ((_ animated: Bool) -> Void)?

    @ObservationIgnored private let agent: LaunchAgent

    init(agent: LaunchAgent) {
        self.agent = agent
        delay = Preferences.delay
        if LegacyAgentMigration.run(label: agent.label) {
            _ = agent.setEnabled(true)
        }
        agent.refreshRegistrationIfUpdated()
        refresh()
    }

    /// Re-reads state that can also change in System Settings.
    func refresh() {
        apply(agent.state(), animated: false)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        guard !isBusy else { return }
        guard enabled != isEnabled else { return }
        isBusy = true
        let agent = agent

        Task {
            let state = await Task.detached { agent.setEnabled(enabled) }.value
            isBusy = false
            apply(state, animated: true)
            if isEnabled != enabled {
                NSSound.beep()
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Could not change login item: \(error.localizedDescription)")
            NSSound.beep()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func lockNow() {
        Task.detached { ScreenLocker.lockNow() }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Turns everything off, deletes Hardlock's preferences, moves the app to the Trash and quits.
    func uninstall() {
        isBusy = true
        let agent = agent

        Task {
            _ = await Task.detached { agent.setEnabled(false) }.value
            try? await SMAppService.mainApp.unregister()
            if let domain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: domain)
            }

            let app = Bundle.main.bundleURL
            do {
                try FileManager.default.trashItem(at: app, resultingItemURL: nil)
                Log.app.notice("Uninstalled")
            } catch {
                // No write access to the app's folder: show it so it can be dragged to the Trash.
                Log.app.error("Could not move app to Trash: \(error.localizedDescription)")
                NSWorkspace.shared.activateFileViewerSelecting([app])
            }
            NSApp.terminate(nil)
        }
    }

    private func apply(_ state: LaunchAgent.State, animated: Bool) {
        needsApproval = state == .needsApproval
        let enabled = state == .enabled
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        onEnabledChange?(animated)
    }
}
