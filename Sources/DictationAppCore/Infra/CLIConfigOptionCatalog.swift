import Foundation

public struct CLIConfigOptionCatalog {
    public static let customEntryLabel = "Custom..."

    private static let curatedModels: [String] = [
        "mistralai/mistral-small-3.1-24b-instruct",
        "openai/gpt-4o-mini",
        "openai/gpt-4.1-mini",
        "anthropic/claude-3.5-sonnet",
        "google/gemini-2.0-flash-001",
        "meta-llama/llama-3.3-70b-instruct",
    ]

    private static let hotkeyPresets: [String] = [
        "ctrl+shift+space",
        "ctrl+option+space",
        "ctrl+shift+d",
        "option+space",
        "cmd+shift+space",
    ]

    private static let asrModels: [String] = [
        "moonshine",
        "moonshine-small",
        "moonshine-base",
        "moonshine-tiny",
        "qwen3-asr-1.7b",
        "qwen3-asr-0.6b",
        "openai/whisper-small",
        "openai/whisper-medium",
    ]

    public static func modelChoices(current: String) -> [String] {
        var choices: [String] = []
        choices.append(current)
        choices.append(contentsOf: curatedModels)
        choices.append(customEntryLabel)
        return orderedUnique(choices)
    }

    public static func hotkeyChoices(current: String, defaultShortcut: String) -> [String] {
        var choices: [String] = []
        choices.append("Keep current (\(current))")
        choices.append("Reset to default (\(defaultShortcut))")
        choices.append(contentsOf: hotkeyPresets)
        choices.append(customEntryLabel)
        return orderedUnique(choices)
    }

    public static func asrModelChoices(current: String) -> [String] {
        var choices: [String] = []
        choices.append(current)
        choices.append(contentsOf: asrModels)
        choices.append(customEntryLabel)
        return orderedUnique(choices)
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for value in values {
            if seen.insert(value).inserted {
                ordered.append(value)
            }
        }
        return ordered
    }
}
