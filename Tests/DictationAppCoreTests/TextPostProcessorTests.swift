import Testing
@testable import DictationAppCore

struct TextPostProcessorTests {
    @Test
    func cleansWhitespaceAndAddsSentencePunctuation() {
        let processor = DeterministicTextPostProcessor()
        let cleaned = processor.clean("   hello   world  ")

        #expect(cleaned == "Hello world.")
    }

    @Test
    func keepsExistingSentenceTerminator() {
        let processor = DeterministicTextPostProcessor()
        let cleaned = processor.clean("already done!")

        #expect(cleaned == "Already done!")
    }
}
