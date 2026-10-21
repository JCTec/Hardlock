import SwiftUI

/// One binary, two roles: the menu bar app, or the LaunchAgent's lock routine.
/// Running the agent from Hardlock's own executable is what makes macOS list it
/// as Hardlock in Login Items, rather than as a script interpreter.
@main
@MainActor
enum Main {
    static func main() {
        if CommandLine.arguments.contains(ScreenLocker.agentArgument) {
            ScreenLocker.lockAfterLogin()
        } else {
            HardlockApp.main()
        }
    }
}

struct HardlockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = HardlockModel(agent: LaunchAgent(label: "com.user.hardlock"))
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement covers the bundled app; this also keeps `swift run` out of the Dock.
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(model: model)
    }
}
