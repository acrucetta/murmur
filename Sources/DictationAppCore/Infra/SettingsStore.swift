public struct DictationSettings: Equatable, Sendable {
    public var shortcutIdentifier: String
    public var preferredModelSize: String
    public var showHUD: Bool

    public init(shortcutIdentifier: String, preferredModelSize: String, showHUD: Bool) {
        self.shortcutIdentifier = shortcutIdentifier
        self.preferredModelSize = preferredModelSize
        self.showHUD = showHUD
    }
}

public protocol SettingsStoring {
    func load() -> DictationSettings
    func save(_ settings: DictationSettings)
}

public final class InMemorySettingsStore: SettingsStoring {
    private var current: DictationSettings

    public init(initial: DictationSettings = .init(shortcutIdentifier: "ctrl+space", preferredModelSize: "base", showHUD: true)) {
        current = initial
    }

    public func load() -> DictationSettings {
        current
    }

    public func save(_ settings: DictationSettings) {
        current = settings
    }
}
