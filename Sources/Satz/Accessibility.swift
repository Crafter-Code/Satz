import AppKit
import ApplicationServices
import Carbon
import SatzCore

struct FieldSnapshot {
    let element: AXUIElement
    let pid: pid_t
    let bundle: String
    let text: String
    let range: CFRange
    let caret: CGRect
    let font: NSFont
    var prefix: String { (text as NSString).substring(to: range.location) }
    var suffix: String { (text as NSString).substring(from: range.location + range.length) }
    func same(as other: FieldSnapshot) -> Bool {
        pid == other.pid && CFEqual(element, other.element) && text == other.text && range.location == other.range.location && range.length == other.range.length
    }
}

enum Accessibility {
    static var lastIssue = "No external field sampled yet"
    static var trusted: Bool { AXIsProcessTrusted() }

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func snapshot(preferences: Preferences) -> FieldSnapshot? {
        guard trusted else { lastIssue = "Accessibility permission required"; return nil }
        guard !IsSecureEventInputEnabled() else { lastIssue = "Secure input is active"; return nil }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        guard let bundle = app.bundleIdentifier, preferences.allows(bundle) else { lastIssue = "Application excluded"; return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.12)
        guard let focused = attribute(root, kAXFocusedUIElementAttribute) else { lastIssue = "No accessible focused field"; return nil }
        guard CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""
        guard role == kAXTextAreaRole || role == kAXTextFieldRole || role == kAXComboBoxRole,
              subrole != kAXSecureTextFieldSubrole else { lastIssue = "\(bundle) · unsupported or secure role: \(role)"; return nil }
        let title = attribute(root, kAXFocusedWindowAttribute).flatMap { window -> String? in
            guard CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
            return attribute(window as! AXUIElement, kAXTitleAttribute) as? String
        } ?? ""
        let lower = title.lowercased()
        guard !["private browsing", "incognito", "inprivate", "password", "keychain"].contains(where: lower.contains) else { lastIssue = "Private or sensitive window excluded"; return nil }
        guard let text = attribute(element, kAXValueAttribute) as? String, text.utf16.count < 250_000,
              let selection = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(selection) == AXValueGetTypeID() else { lastIssue = "Field value or selection unavailable"; return nil }
        var range = CFRange()
        guard AXValueGetValue(selection as! AXValue, .cfRange, &range), range.length == 0,
              range.location >= 0, range.location <= text.utf16.count else { lastIssue = "Selection is nonempty or invalid"; return nil }
        let local = String((text as NSString).substring(to: range.location).suffix(600))
        guard !TextRules.isSensitive(local) else { lastIssue = "Sensitive text pattern excluded"; return nil }
        guard let caret = bounds(element: element, range: range), caret.width.isFinite, caret.height.isFinite,
              caret.height > 0, caret.height < 200 else { lastIssue = "Caret bounds unavailable"; return nil }
        lastIssue = "Eligible field · \(bundle) · caret \(Int(caret.height)) pt"
        let font = fieldFont(element, location: range.location, caretHeight: caret.height)
        return FieldSnapshot(element: element, pid: app.processIdentifier, bundle: bundle, text: text, range: range, caret: caret, font: font)
    }

    private static func fieldFont(_ element: AXUIElement, location: Int, caretHeight: CGFloat) -> NSFont {
        var range = CFRange(location: max(0, location - 1), length: location > 0 ? 1 : 0)
        var result: CFTypeRef?
        if let boxed = AXValueCreate(.cfRange, &range),
           AXUIElementCopyParameterizedAttributeValue(element, kAXAttributedStringForRangeParameterizedAttribute as CFString, boxed, &result) == .success,
           let attributed = result as? NSAttributedString, attributed.length > 0 {
            let values = attributed.attributes(at: 0, effectiveRange: nil)
            if let font = values[.font] as? NSFont { return font }
            if let ax = values[NSAttributedString.Key("AXFont")] as? [String: Any],
               let size = ax["AXFontSize"] as? NSNumber {
                let name = ax["AXFontName"] as? String ?? ""
                return NSFont(name: name, size: size.doubleValue) ?? NSFont.systemFont(ofSize: size.doubleValue)
            }
        }
        return NSFont.systemFont(ofSize: max(10, min(24, caretHeight * 0.85)))
    }

    static func bounds(element: AXUIElement, range: CFRange) -> CGRect? {
        var input = range
        guard let boxed = AXValueCreate(.cfRange, &input) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, boxed, &result) == .success,
              let result, CFGetTypeID(result) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(result as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    static let ownEvent: Int64 = 0x5341545A

    static func insert(_ text: String, replacing length: Int, snapshot: FieldSnapshot, preferences: Preferences) -> Bool {
        guard let now = self.snapshot(preferences: preferences), snapshot.same(as: now), !text.isEmpty else { return false }
        // Native Unicode keyboard input keeps the host application's editing and Undo path.
        // The clipboard is never read, overwritten or restored.
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let chunks = TextRules.unicodeChunks(text)
        guard !chunks.isEmpty, text.utf16.count <= 250 else { return false }
        var events: [(CGEvent, CGEvent)] = []
        for units in chunks {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return false }
            down.flags = []; up.flags = []
            down.setIntegerValueField(.eventSourceUserData, value: ownEvent)
            up.setIntegerValueField(.eventSourceUserData, value: ownEvent)
            units.withUnsafeBufferPointer { buffer in
                down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
                up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
            }
            events.append((down, up))
        }
        if length > 0 {
            guard length <= snapshot.range.location else { return false }
            var selection = CFRange(location: snapshot.range.location - length, length: length)
            guard let boxed = AXValueCreate(.cfRange, &selection),
                  AXUIElementSetAttributeValue(snapshot.element, kAXSelectedTextRangeAttribute as CFString, boxed) == .success else { return false }
        }
        // Quartz text payloads are limited to short UTF-16 runs. Do not split
        // surrogate pairs or grapheme clusters, and target the validated process.
        for (down, up) in events { down.postToPid(snapshot.pid); up.postToPid(snapshot.pid) }
        return true
    }
}

final class KeyboardHook {
    var onKey: ((Int64, CGEventFlags) -> Bool)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var active: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.scrollWheel.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let hook = Unmanaged<KeyboardHook>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = hook.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            if event.getIntegerValueField(.eventSourceUserData) == Accessibility.ownEvent { return Unmanaged.passUnretained(event) }
            let code = type == .keyDown ? event.getIntegerValueField(.keyboardEventKeycode) : -1
            if hook.onKey?(code, event.flags) == true { return nil }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil
    }
    deinit { stop() }
}
