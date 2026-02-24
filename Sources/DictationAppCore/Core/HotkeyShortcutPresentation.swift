public enum HotkeyShortcutPresentation {
    public static func label(for shortcut: HotkeyShortcut) -> String {
        let tokens = shortcut.identifier.split(separator: "+").map(String.init)
        return tokens.map(displayToken(for:)).joined(separator: " + ")
    }

    public static func overlayPrompt(for shortcut: HotkeyShortcut, toggleMode: Bool = false) -> String {
        if toggleMode {
            return "Press \(label(for: shortcut)) to start dictating"
        }
        return "Hold \(label(for: shortcut)) to start dictating"
    }

    private static func displayToken(for token: String) -> String {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count == 1 {
            return normalized.uppercased()
        }
        return normalized
    }
}
