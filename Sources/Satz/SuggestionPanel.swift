import AppKit
import SwiftUI

private final class GhostView: NSView {
    var text = ""
    var font = NSFont.systemFont(ofSize: 12)
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        (text as NSString).draw(at: NSPoint(x: 1, y: -1), withAttributes: [.font: font, .foregroundColor: NSColor.systemGray.withAlphaComponent(0.8)])
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class SuggestionPanel: NSObject {
    private let panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        return panel
    }()
    private let popover = NSPopover()
    private var origin = ""
    private var sourceURL: String?
    private var infoButton: NSButton?
    var isShowingDetails: Bool { popover.isShown }
    var containsPointer: Bool {
        let point = NSEvent.mouseLocation
        if panel.isVisible && panel.frame.contains(point) { return true }
        return popover.isShown && (popover.contentViewController?.view.window?.frame.contains(point) ?? false)
    }

    func show(text: String, origin: String, source: Bool, sourceURL: String?, caret: CGRect, font: NSFont, inline: Bool) {
        self.origin = origin; self.sourceURL = sourceURL
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        let point = NSPoint(x: caret.minX, y: primaryTop - caret.maxY)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height = max(caret.height, ceil(font.ascender - font.descender + 1))
        let available = max(45, visible.maxX - point.x - 24)
        let textWidth = min(ceil((text as NSString).size(withAttributes: [.font: font]).width) + 3, min(420, available))
        let width = textWidth + 18
        var y = inline ? point.y : point.y - height - 2
        if y < visible.minY { y = primaryTop - caret.minY + 2 }
        let x = min(max(point.x + 1, visible.minX + 3), visible.maxX - width - 3)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        let ghost = GhostView(frame: NSRect(x: 0, y: 0, width: textWidth, height: height))
        ghost.text = text; ghost.font = font; content.addSubview(ghost)
        ghost.setAccessibilityElement(true); ghost.setAccessibilityRole(.staticText)
        ghost.setAccessibilityValue(text); ghost.setAccessibilityLabel("Writing suggestion")
        let info = NSButton(frame: NSRect(x: textWidth + 2, y: max(0, (height - 12) / 2), width: 12, height: 12))
        info.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Suggestion details")
        info.imageScaling = .scaleProportionallyDown; info.isBordered = false
        info.contentTintColor = .tertiaryLabelColor
        info.target = self; info.action = #selector(showDetails)
        info.toolTip = "Suggestion details and source"
        content.addSubview(info); infoButton = info
        panel.contentView = content
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.orderFrontRegardless()
    }

    @objc private func showDetails() {
        guard let infoButton else { return }
        let content = NSHostingController(rootView: VStack(alignment: .leading, spacing: 10) {
            Text(origin).font(.system(size: 12, weight: .semibold))
            if let sourceURL, let url = URL(string: sourceURL) {
                Text("Source-linked reference. Review the original context before relying on it.").font(.system(size: 11)).foregroundStyle(.secondary)
                Link("Open source · \(url.host ?? "reference")", destination: url).font(.system(size: 11))
            } else {
                Text("A local writing suggestion, not a verified factual claim.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text("Tab: next word · Shift–Tab: all · Esc: dismiss").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(14).frame(width: 280, alignment: .leading))
        popover.contentViewController = content; popover.behavior = .transient
        popover.show(relativeTo: infoButton.bounds, of: infoButton, preferredEdge: .maxY)
    }
    func hide() { popover.close(); panel.orderOut(nil) }
}
