import Testing
@testable import DictationAppCore

struct TextPostProcessorTests {
    @Test
    func cleansWhitespaceAndAddsSentencePunctuation() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("   hello   world  ")

        #expect(cleaned == "Hello world.")
    }

    @Test
    func keepsExistingSentenceTerminator() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("already done!")

        #expect(cleaned == "Already done!")
    }

    @Test
    func collapsesImmediateStutterForFunctionWords() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("i i i think we should should ship this")

        #expect(cleaned == "I think we should ship this.")
    }

    @Test
    func keepsIntentionalDoubleEmphasisByDefault() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("this is very very good")

        #expect(cleaned == "This is very very good.")
    }

    @Test
    func appliesStrongBacktrackForScratchThat() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("send it tomorrow scratch that send it friday")

        #expect(cleaned == "Send it friday.")
    }

    @Test
    func appliesStrongBacktrackForNoWait() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("book the meeting no wait book it next week")

        #expect(cleaned == "Book it next week.")
    }

    @Test
    func appliesSoftRepairForIMean() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("we should deploy monday i mean tuesday")

        #expect(cleaned == "We should deploy tuesday.")
    }

    @Test
    func removesLeadingActuallyMarker() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("actually let's do this now")

        #expect(cleaned == "Let's do this now.")
    }

    @Test
    func appliesActuallyAsRepairMarkerMidSentence() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("ship tomorrow actually friday")

        #expect(cleaned == "Ship friday.")
    }

    @Test
    func removesActuallyWithoutDroppingSubjectInNormalGrammar() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("we actually should go now")

        #expect(cleaned == "We should go now.")
    }

    @Test
    func doesNotDropContextWhenIMeanIsNotClearlyReplacingContentWord() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("this i mean is fine")

        #expect(cleaned == "This is fine.")
    }

    @Test
    func doesNotReplacePreviousWordForActuallyWhenNextWordIsFunctionWord() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("meeting tomorrow actually is canceled")

        #expect(cleaned == "Meeting tomorrow is canceled.")
    }

    @Test
    func convertsSpokenExclamationMark() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("that is great exclamation mark")

        #expect(cleaned == "That is great!")
    }

    @Test
    func convertsSpokenQuestionMark() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("are you coming question mark")

        #expect(cleaned == "Are you coming?")
    }

    @Test
    func convertsSpokenAtSymbolForEmailLikeContext() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("send this to jane at sign example.com")

        #expect(cleaned == "Send this to jane@example.com.")
    }

    @Test
    func keepsSpacesAroundAtSymbolInAmbiguousContext() {
        let processor = TextPostProcessorV2()
        let cleaned = processor.clean("look at symbol this")

        #expect(cleaned == "Look @ this.")
    }

    @Test
    func convertsSpokenSymbolsInLiteralMode() {
        let processor = TextPostProcessorV2(mode: .literal)
        let cleaned = processor.clean("nice work exclamation mark")

        #expect(cleaned == "Nice work!")
    }
}
