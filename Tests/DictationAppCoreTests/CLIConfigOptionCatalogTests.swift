import XCTest
@testable import DictationAppCore

final class CLIConfigOptionCatalogTests: XCTestCase {
    func testModelChoicesIncludesCurrentAndCustom() {
        let choices = CLIConfigOptionCatalog.modelChoices(current: "custom/provider-model")

        XCTAssertEqual(choices.first, "custom/provider-model")
        XCTAssertTrue(choices.contains("mistralai/mistral-small-3.1-24b-instruct"))
        XCTAssertEqual(choices.last, CLIConfigOptionCatalog.customEntryLabel)
    }

    @Test
    func hotkeyChoicesIncludeKeepResetAndCustom() {
        let choices = CLIConfigOptionCatalog.hotkeyChoices(current: "ctrl+option+space", defaultShortcut: "ctrl+shift+space")

        #expect(choices.first == "Keep current (ctrl+option+space)")
        #expect(choices.contains("Reset to default (ctrl+shift+space)"))
        #expect(choices.last == CLIConfigOptionCatalog.customEntryLabel)
    }
}
