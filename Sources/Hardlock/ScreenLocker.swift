import ApplicationServices
import Darwin
import Foundation
import IOKit
import os

enum Log {
    static let app = Logger(subsystem: "com.user.hardlock.app", category: "app")
    static let lock = Logger(subsystem: "com.user.hardlock.app", category: "lock")
}

enum Preferences {
    static let delayKey = "lockDelay"
    static let defaultDelay = 5
    static let delayRange = 0...60

    static var delay: Int {
        guard UserDefaults.standard.object(forKey: delayKey) != nil else { return defaultDelay }
        return UserDefaults.standard.integer(forKey: delayKey).clamped(to: delayRange)
    }
}

/// Locks the screen. Runs inside the LaunchAgent (`Hardlock --lock-after-login`)
/// and behind Settings › Lock Now.
enum ScreenLocker {
    static let agentArgument = "--lock-after-login"

    /// The agent only acts this soon after boot, i.e. after the automatic login.
    /// Registering the agent also triggers RunAtLoad; this keeps that from locking.
    static let maxSecondsSinceBoot: TimeInterval = 300

    /// LaunchAgent entry point.
    static func lockAfterLogin() {
        guard let sinceBoot = secondsSinceBoot(), sinceBoot < maxSecondsSinceBoot else {
            Log.lock.info("Not a fresh login; skipping")
            return
        }
        let delay = Preferences.delay
        Log.lock.info("Locking in \(delay)s")
        Thread.sleep(forTimeInterval: TimeInterval(delay))
        lockNow()
    }

    static func lockNow() {
        if lockImmediately() {
            Log.lock.notice("Locked screen")
        } else if postLockShortcut() {
            Log.lock.notice("Locked screen via Ctrl-Cmd-Q")
        } else if sleepDisplay() {
            Log.lock.notice("Slept display")
        } else {
            Log.lock.error("Could not lock screen")
        }
    }

    /// `SACLockScreenImmediate` from the private login.framework: the same lock as
    /// Lock Screen in the Apple menu, with no permissions needed. Looked up at
    /// runtime so a future macOS without it falls through to the next method.
    private static func lockImmediately() -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate")
        else { return false }
        typealias LockFunction = @convention(c) () -> Int32
        let lock = unsafeBitCast(symbol, to: LockFunction.self)
        return lock() == 0
    }

    /// Ctrl-Cmd-Q. Only works once Hardlock has Accessibility access.
    private static func postLockShortcut() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let qKey: CGKeyCode = 12
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: qKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: qKey, keyDown: false)
        else { return false }
        down.flags = [.maskControl, .maskCommand]
        up.flags = [.maskControl, .maskCommand]
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    /// Same as `pmset displaysleepnow`. Locks only if a password is required
    /// immediately after the display sleeps.
    private static func sleepDisplay() -> Bool {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayWrapper"))
        guard entry != 0 else { return false }
        defer { IOObjectRelease(entry) }
        return IORegistryEntrySetCFProperty(entry, "IORequestIdle" as CFString, kCFBooleanTrue) == KERN_SUCCESS
    }

    /// Wall-clock time since boot (unlike `systemUptime`, includes time asleep).
    private static func secondsSinceBoot() -> TimeInterval? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 else { return nil }
        return Date().timeIntervalSince1970 - TimeInterval(bootTime.tv_sec)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
