import Testing
@testable import DictationAppCore

struct CLIConfigOptionCatalogTests {
    @Test
    func modelChoicesIncludesCurrentAndCustom() {
        let choices = CLIConfigOptionCatalog.modelChoices(current: "custom/provider-model")

        #expect(choices.first == "custom/provider-model")
        #expect(choices.contains("mistralai/mistral-small-3.1-24b-instruct"))
        #expect(choices.last == CLIConfigOptionCatalog.customEntryLabel)
    }

    @Test
    func hotkeyChoicesIncludeKeepResetAndCustom() {
        let choices = CLIConfigOptionCatalog.hotkeyChoices(current: "ctrl+option+space", defaultShortcut: "ctrl+shift+space")

        #expect(choices.first == "Keep current (ctrl+option+space)")
        #expect(choices.contains("Reset to default (ctrl+shift+space)"))
        #expect(choices.last == CLIConfigOptionCatalog.customEntryLabel)
    }

    @Test
    func asrModelChoicesIncludeCuratedValues() {
        let choices = CLIConfigOptionCatalog.asrModelChoices(current: "qwen3-asr-1.7b")

        #expect(choices.first == "qwen3-asr-1.7b")
        #expect(choices.contains("moonshine"))
        #expect(choices.contains("moonshine-small"))
        #expect(choices.contains("qwen3-asr-0.6b"))
        #expect(choices.contains("openai/whisper-small"))
        #expect(choices.last == CLIConfigOptionCatalog.customEntryLabel)
    }
}
