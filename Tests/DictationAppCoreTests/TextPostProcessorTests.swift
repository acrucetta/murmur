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
}
