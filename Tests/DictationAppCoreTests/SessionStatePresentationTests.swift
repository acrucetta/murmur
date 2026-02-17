import Foundation
import Testing
@testable import DictationAppCore

struct SessionStatePresentationTests {
    @Test
    func mapsStatesToHumanReadableLabels() {
        #expect(SessionStatePresentation.label(for: .idle) == "Idle")
        #expect(SessionStatePresentation.label(for: .listening) == "Listening")
        #expect(SessionStatePresentation.label(for: .finalizing) == "Finalizing")
        #expect(SessionStatePresentation.label(for: .inserting) == "Inserting")
        #expect(SessionStatePresentation.label(for: .error(.engineError)) == "Error: engine_error")
    }
}
