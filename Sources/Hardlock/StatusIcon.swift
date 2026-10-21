import AppKit
import SwiftUI

/// The two padlock glyphs, as template images for the status item button.
enum StatusIcon {
    static func symbolName(enabled: Bool) -> String {
        enabled ? "lock.fill" : "lock.open"
    }

    @MainActor
    static func image(enabled: Bool) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName(enabled: enabled), accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}

@MainActor
@Observable
final class StatusIconModel {
    var isEnabled = false
    /// Shown only while a symbol transition plays; at rest the button's template image is visible.
    var isAnimating = false
    var bounceCount = 0
}

/// Draws the padlock during state changes so SwiftUI symbol effects can animate the swap.
struct StatusIconView: View {
    let model: StatusIconModel

    var body: some View {
        Image(systemName: StatusIcon.symbolName(enabled: model.isEnabled))
            .font(.system(size: 13, weight: .regular))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: model.bounceCount)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(model.isAnimating ? 1 : 0)
            .accessibilityHidden(true)
    }
}

/// Hosting view that never takes mouse events, so clicks reach the status bar button beneath it.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
