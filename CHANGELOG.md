# Changelog

## 1.1.0

- **The agent is now part of the app.** It ships inside `Hardlock.app` and is registered with `SMAppService`. Login Items and the "Background Items Added" notification show **Hardlock** with its icon, not `bash`.
- **No install scripts.** Drag the app to Applications, open it, click the padlock.
- **Native screen lock.** Uses the same lock as  › Lock Screen, with no Accessibility or Automation permission prompts. Falls back to ⌃⌘Q, then to display sleep.
- **Settings window:** lock after login, delay after login, open Hardlock at login, Lock Now (test), and Uninstall.
- **Status: Needs Approval** appears when Hardlock is switched off in System Settings › Login Items, with a button that opens Login Items.
- **Automatic migration from 1.0.** Removes the old `~/Library/LaunchAgents` agent and script, and keeps your on/off setting.
- **Re-registers after updates**, so the background item always matches the installed copy.
- **App icon.**
- **Signed and notarized** with a Developer ID. Universal binary (Apple silicon + Intel).

## 1.0.0

- First release: a menu bar toggle for a script-based LaunchAgent that locks the screen after an automatic login.
