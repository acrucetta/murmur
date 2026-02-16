import Foundation
import Testing
@testable import DictationAppCore

struct StateMachineTests {
    @Test
    func happyPathReturnsToIdle() {
        let machine = StateMachine()
        var state: SessionState = .idle

        state = machine.nextState(from: state, event: .shortcutPressed(.init(timestamp: Date())))
        #expect(state == .listening)

        state = machine.nextState(from: state, event: .shortcutReleased(.init(timestamp: Date())))
        #expect(state == .finalizing)

        state = machine.nextState(
            from: state,
            event: .finalTranscript(.init(text: "hello world", confidence: 0.9))
        )
        #expect(state == .inserting)

        state = machine.nextState(
            from: state,
            event: .insertResult(.init(success: true, method: .accessibilityDirect, error: nil))
        )
        #expect(state == .idle)
    }

    @Test
    func insertionFailureTransitionsToError() {
        let machine = StateMachine()
        let state = machine.nextState(
            from: .inserting,
            event: .insertResult(.init(success: false, method: .clipboardPaste, error: .insertionFailed))
        )

        #expect(state == .error(.insertionFailed))
    }

    @Test
    func errorCanResetToIdle() {
        let machine = StateMachine()
        let state = machine.nextState(from: .error(.permissionDenied), event: .reset)

        #expect(state == .idle)
    }

    @Test
    func invalidTransitionIsNoOp() {
        let machine = StateMachine()
        let state = machine.nextState(
            from: .idle,
            event: .finalTranscript(.init(text: "orphan final transcript", confidence: nil))
        )

        #expect(state == .idle)
    }
}
