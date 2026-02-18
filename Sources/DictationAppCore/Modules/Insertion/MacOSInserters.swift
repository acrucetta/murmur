import Foundation
#if canImport(AppKit)
import AppKit
import ApplicationServices
#endif

enum InsertionSurfacePolicy {
    static let forcedClipboardBundleIdentifiers: Set<String> = [
        "com.apple.notes",
        "com.apple.terminal",
        "com.github.wez.wezterm",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.warp-stable",
        "net.kovidgoyal.kitty",
        "org.alacritty",
    ]

    static func requiresClipboardFallback(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        let normalized = bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return false
        }

        return forcedClipboardBundleIdentifiers.contains(normalized)
    }
}

#if canImport(AppKit)
public final class AccessibilityDirectInserter: AccessibilityDirectInserting {
    private let frontmostBundleIdentifier: () -> String?

    public init(
        frontmostBundleIdentifier: @escaping () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
    ) {
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
    }

    public func insertDirect(_ text: String) -> InsertResult {
        if InsertionSurfacePolicy.requiresClipboardFallback(bundleIdentifier: frontmostBundleIdentifier()) {
            return .init(success: false, method: .accessibilityDirect, error: .insertionFailed)
        }

        guard AXIsProcessTrusted() else {
            return .init(success: false, method: .accessibilityDirect, error: .permissionDenied)
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusError = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusError == .success, let focusedRef else {
            return .init(success: false, method: .accessibilityDirect, error: mapAXError(focusError))
        }

        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return .init(success: false, method: .accessibilityDirect, error: .noFocusedField)
        }

        let focusedElement = unsafeDowncast(focusedRef, to: AXUIElement.self)
        let selectedTextError = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        if selectedTextError == .success {
            return .init(success: true, method: .accessibilityDirect, error: nil)
        }

        let valueError = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )
        if valueError == .success {
            return .init(success: true, method: .accessibilityDirect, error: nil)
        }

        return .init(success: false, method: .accessibilityDirect, error: mapAXError(selectedTextError))
    }

    private func mapAXError(_ error: AXError) -> FailureCode {
        switch error {
        case .apiDisabled:
            return .permissionDenied
        case .noValue, .invalidUIElement, .attributeUnsupported:
            return .noFocusedField
        case .cannotComplete:
            return .secureInputBlocked
        default:
            return .insertionFailed
        }
    }
}

public final class ClipboardFallbackInserter: ClipboardFallbackPasting {
    private let pasteboard: NSPasteboard
    private let eventPoster: CGEventPosting
    private let sleeper: (TimeInterval) -> Void

    public init(
        pasteboard: NSPasteboard = .general,
        eventPoster: CGEventPosting = SystemCGEventPoster(),
        sleeper: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) {
        self.pasteboard = pasteboard
        self.eventPoster = eventPoster
        self.sleeper = sleeper
    }

    public func paste(_ text: String) -> InsertResult {
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        defer { snapshot.restore(into: pasteboard) }

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return .init(success: false, method: .clipboardPaste, error: .insertionFailed)
        }

        guard eventPoster.postCommandV() else {
            return .init(success: false, method: .clipboardPaste, error: .permissionDenied)
        }

        sleeper(0.05)
        return .init(success: true, method: .clipboardPaste, error: nil)
    }
}

public protocol CGEventPosting {
    func postCommandV() -> Bool
}

public struct SystemCGEventPoster: CGEventPosting {
    public init() {}

    public func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        guard let existingItems = pasteboard.pasteboardItems else {
            return PasteboardSnapshot(items: [])
        }

        let serializedItems = existingItems.map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
        return PasteboardSnapshot(items: serializedItems)
    }

    func restore(into pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        for itemData in items {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}
#else
public final class AccessibilityDirectInserter: AccessibilityDirectInserting {
    public init() {}

    public func insertDirect(_ text: String) -> InsertResult {
        .init(success: false, method: .accessibilityDirect, error: .insertionFailed)
    }
}

public final class ClipboardFallbackInserter: ClipboardFallbackPasting {
    public init() {}

    public func paste(_ text: String) -> InsertResult {
        .init(success: false, method: .clipboardPaste, error: .insertionFailed)
    }
}

public protocol CGEventPosting {
    func postCommandV() -> Bool
}

public struct SystemCGEventPoster: CGEventPosting {
    public init() {}

    public func postCommandV() -> Bool { false }
}
#endif
