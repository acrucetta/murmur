#if canImport(AppKit)
import AppKit
import Testing
@testable import DictationAppCore

struct MenuBarSettingsContractsTests {
    @Test
    func snapshotCarriesASRModel() {
        let snapshot = MenuBarSettingsSnapshot(
            shortcutIdentifier: "ctrl+shift+space",
            rewriteMode: .literal,
            asrModel: "qwen3-asr-1.7b",
            openRouterModel: "openai/gpt-4.1-mini",
            pauseMediaWhileRecording: false,
            preferredMicrophone: nil,
            availableMicrophones: []
        )

        #expect(snapshot.asrModel == "qwen3-asr-1.7b")
    }

    @Test
    func settingsActionSupportsASRModelSelection() {
        let action = MenuBarSettingsAction.setASRModel("moonshine-small")

        switch action {
        case .setASRModel(let model):
            #expect(model == "moonshine-small")
        default:
            Issue.record("unexpected action case")
        }
    }
}
#endif
