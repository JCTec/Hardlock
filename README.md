# Hardlock

A tiny macOS menu bar utility that toggles **"lock the screen shortly after automatic login"** on a headless Mac (a Mac mini in a closet, a home server, a build box).

Automatic login lets a headless Mac come back from a reboot or power cut with a full GUI session: login items, Screen Sharing, apps that need a logged-in user. The catch is that the session sits unlocked. Hardlock locks it a few seconds after login, so the session keeps running behind the lock screen.

- Menu bar only: no Dock icon.
- **Left-click** the padlock to toggle. **Right-click** (or **⌃-click**) for the menu.
- `lock.fill` = enabled, `lock.open` = disabled. The icon always shows the saved state. If a change fails you hear a beep and the icon stays as it was.
- **Settings…** (⌘,) in the menu sets the delay after login and whether Hardlock opens at login. It also has a **Lock Now** button for testing and an **Uninstall…** button.

## Requirements

- macOS 14 Sonoma or later
- To build: Swift 6 toolchain (Xcode 16 or later)

## Install

1. Download `Hardlock-<version>.dmg` from [Releases](https://github.com/JCTec/Hardlock/releases/latest). Open it and drag **Hardlock** to **Applications**. If you're upgrading, quit Hardlock and delete the old copy first.
2. Open Hardlock and click the padlock.

That's all. There's nothing else to install. macOS shows a "Background Items Added" notification for **Hardlock**, and it appears under **System Settings › General › Login Items & Extensions**.

Keep the app in `/Applications`. The background item is registered from inside the app bundle, so moving or deleting the app removes it.

Release DMGs are signed with a Developer ID and notarized by Apple, so they open without Gatekeeper warnings.

### Verify the download

Each release lists the DMG's SHA-256 checksum and attaches it as `Hardlock-<version>.dmg.sha256`. To check your download:

```sh
cd ~/Downloads
shasum -a 256 -c Hardlock-1.1.0.dmg.sha256
# Hardlock-1.1.0.dmg: OK
```

## Build

```sh
git clone https://github.com/JCTec/Hardlock.git
cd Hardlock

make run       # build build/Hardlock.app and open it
make install   # quit and remove the installed copy, then copy the new build to /Applications
make dmg       # universal (Apple silicon + Intel) build/Hardlock-<version>.dmg
```

The build signs with the first **Developer ID Application** identity in your keychain, using the hardened runtime. Set `SIGN_IDENTITY` to choose a different one. Set `NOTARY_PROFILE` to make `make dmg` notarize and staple the DMG, using a profile saved with `xcrun notarytool store-credentials <profile>`. The build also writes `build/Hardlock-<version>.dmg.sha256`. Ad-hoc signing (`SIGN_IDENTITY=-`) builds and runs, but macOS files an unsigned app's background item under "Unknown Developer" and may refuse to launch the agent. You can also open `Package.swift` in Xcode.

Test the background item from `/Applications` (`make install`), not from `build/`. Registration points at whichever copy of the app turned it on.

## How it works

The app bundle contains a LaunchAgent, `Contents/Library/LaunchAgents/com.user.hardlock.plist`. It runs Hardlock's own executable with `--lock-after-login`, once per login (`RunAtLoad`, Aqua sessions only).

- **Enable** registers that agent with [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice). **Disable** unregisters it. Hardlock keeps no state of its own: "enabled" means macOS reports the agent as registered and allowed.
- If you switch Hardlock off in Login Items, the menu shows **Status: Needs Approval**, and Settings has a button that opens Login Items.

When the agent runs at login, Hardlock:

1. Does nothing unless the Mac booted less than 5 minutes ago. Registering the agent also triggers `RunAtLoad`, and this check stops that from locking your screen. It also leaves manual logins later on alone.
2. Waits for the delay set in Settings (default 5 seconds).
3. Locks the screen with `SACLockScreenImmediate`. This is the same lock as  › Lock Screen, and it needs no permissions.
4. If that's unavailable, sends **⌃⌘Q**. This only works if you've given Hardlock Accessibility access.
5. Otherwise it puts the display to sleep, like `pmset displaysleepnow`. That locks the session only if **System Settings › Lock Screen › Require password after screen saver begins or display is turned off** is set to **Immediately**.

`SACLockScreenImmediate` is a private API in `login.framework`, loaded at runtime. That's fine for an app distributed outside the Mac App Store, but Apple could remove it in a future macOS; if that happens, the fallbacks take over. Set "Require password… Immediately" anyway, so the last fallback is a real lock too.

Each run is logged to the unified log:

```sh
log show --last 1h --predicate 'subsystem == "com.user.hardlock.app"' --info
```

### Upgrading from 1.0

Hardlock 1.0 installed a script-based agent in `~/Library/LaunchAgents`, which macOS listed as "bash". On first launch, Hardlock 1.1 removes it, along with `~/Library/Application Support/Hardlock`. If the old agent was on, Hardlock turns on the new one.

## Caveats: FileVault and automatic login

Read these before relying on Hardlock.

- **FileVault and automatic login don't mix.** With FileVault on, macOS turns off automatic login. After a cold boot the Mac stops at the FileVault unlock screen, and unlocking it there logs that user in. A headless Mac with FileVault therefore can't boot unattended. `sudo fdesetup authrestart` gets you a single unattended restart, and Hardlock is still useful then.
- **Without FileVault, the disk isn't encrypted at rest.** Locking the screen protects the *running session* from someone at the keyboard or on Screen Sharing. It does nothing against someone who takes the Mac, removes the disk, or boots into another OS. Decide whether that trade-off suits your threat model.
- **There is a short unlocked window.** For the configured delay after login, plus however long the login takes, the session is unlocked. Anyone with physical or remote access during that window gets in.
- **Turning on automatic login** is in **System Settings › Users & Groups › Automatically log in as…**. It's unavailable while FileVault is on, and some MDM profiles block it.

## Uninstall

Open **Settings… › Uninstall…**. Hardlock turns off the lock after login and removes itself from Login Items. It then deletes its settings, moves the app to the Trash and quits.

To do it by hand instead:

1. Left-click the padlock so it shows unlocked. This unregisters the background agent right away.
2. In **Settings…**, switch off **Open Hardlock at login** if you turned it on.
3. Quit Hardlock and move it from Applications to the Trash.
4. Optionally, delete its settings: `defaults delete com.user.hardlock.app`.

Turn it off before you delete the app. If you trash the app while it's on, the agent can stay loaded until you log out.

## Project layout

```
Sources/Hardlock/
  HardlockApp.swift            Entry point (app or agent), App, app delegate
  HardlockModel.swift          Shared state for the status item and Settings
  StatusItemController.swift   Status item, click handling, menu
  StatusIcon.swift             Template glyphs + SwiftUI symbol transition
  SettingsView.swift           Settings window
  LaunchAgent.swift            SMAppService wrapper, 1.0 migration
  ScreenLocker.swift           Lock routine run by the agent
CHANGELOG.md                   Release notes
Resources/
  Info.plist                   LSUIElement app bundle metadata
  LaunchAgents/                Agent plist, copied into the app bundle
  AppIcon/                     App icon sources (light, dark, tinted)
scripts/                       build-app, make-dmg (signing, notarization, checksum)
```

## License

[MIT](LICENSE)
