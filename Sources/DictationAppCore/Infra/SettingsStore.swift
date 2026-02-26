public struct DictationSettings: Equatable, Sendable {
    public var shortcutIdentifier: String
    public var preferredModelSize: String
    public var showHUD: Bool
    public var smartRewriteThreshold: Int

    public init(shortcutIdentifier: String, preferredModelSize: String, showHUD: Bool, smartRewriteThreshold: Int = 3) {
        self.shortcutIdentifier = shortcutIdentifier
        self.preferredModelSize = preferredModelSize
        self.showHUD = showHUD
        self.smartRewriteThreshold = smartRewriteThreshold
    }
}

public protocol SettingsStoring {
    func load() -> DictationSettings
    func save(_ settings: DictationSettings)
}

public final class InMemorySettingsStore: SettingsStoring {
    private var current: DictationSettings

    public init(initial: DictationSettings = .init(shortcutIdentifier: "ctrl+space", preferredModelSize: "base", showHUD: true, smartRewriteThreshold: 3)) {
        current = initial
    }

    public func load() -> DictationSettings {
        current
    }

    public func save(_ settings: DictationSettings) {
        current = settings
    }
}
