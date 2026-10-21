import Foundation
import ServiceManagement

/// The LaunchAgent bundled in Hardlock.app (`Contents/Library/LaunchAgents`),
/// registered through SMAppService so macOS attributes it to Hardlock.
struct LaunchAgent: Sendable {
    enum State: Sendable {
        case enabled
        case disabled
        /// Registered, but switched off in System Settings › Login Items.
        case needsApproval
    }

    let label: String

    private var service: SMAppService {
        .agent(plistName: "\(label).plist")
    }

    func state() -> State {
        switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        default: .disabled
        }
    }

    /// Registers or unregisters the agent and returns the resulting state.
    /// Blocks briefly; call off the main actor.
    func setEnabled(_ enabled: Bool) -> State {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Log.app.error("Could not \(enabled ? "register" : "unregister") \(label): \(error.localizedDescription)")
        }
        let state = state()
        if state == .enabled {
            UserDefaults.standard.set(Self.currentBuild, forKey: Self.registeredBuildKey)
        }
        return state
    }

    /// Re-registers an enabled agent once per app build, so the registration
    /// matches the installed copy's signature after an update.
    func refreshRegistrationIfUpdated() {
        guard state() == .enabled,
              UserDefaults.standard.string(forKey: Self.registeredBuildKey) != Self.currentBuild
        else { return }
        try? service.unregister()
        if setEnabled(true) == .enabled {
            Log.app.notice("Re-registered \(label) for build \(Self.currentBuild ?? "?")")
        }
    }

    private static let registeredBuildKey = "registeredBuild"
    private static var currentBuild: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}

/// Cleans up the v1 agent, which lived in ~/Library/LaunchAgents and ran a bash script.
enum LegacyAgentMigration {
    /// Removes the v1 agent and returns whether it was loaded, so the caller can
    /// carry the enabled state over to the bundled agent.
    static func run(label: String) -> Bool {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let plist = home.appending(path: "Library/LaunchAgents/\(label).plist")
        guard fileManager.fileExists(atPath: plist.path(percentEncoded: false)) else { return false }

        let service = "gui/\(getuid())/\(label)"
        let wasLoaded = launchctl("print", service) == 0
        launchctl("bootout", service)
        // v1's installer marked the label disabled; clear it so SMAppService can load it.
        launchctl("enable", service)
        try? fileManager.removeItem(at: plist)
        try? fileManager.removeItem(at: home.appending(path: "Library/Application Support/Hardlock"))

        Log.app.notice("Removed v1 agent (was \(wasLoaded ? "enabled" : "disabled"))")
        return wasLoaded
    }

    @discardableResult
    private static func launchctl(_ arguments: String...) -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
