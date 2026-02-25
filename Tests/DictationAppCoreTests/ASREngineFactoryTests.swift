import Testing
@testable import DictationAppCore

struct ASREngineFactoryTests {
    @Test
    func infersMoonshineRuntimeFromCommand() {
        let runtime = ASREngineFactory.inferRuntime(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            model: "medium-streaming-en"
        )

        #expect(runtime == .moonshine)
    }

    @Test
    func infersGenericRuntimeFromCommand() {
        let runtime = ASREngineFactory.inferRuntime(
            command: ["python3", "scripts/hf_asr_transcribe.py"],
            model: "qwen3-asr-1.7b"
        )

        #expect(runtime == .generic)
    }

    @Test
    func infersMoonshineRuntimeFromModelWhenCommandIsAmbiguous() {
        let runtime = ASREngineFactory.inferRuntime(
            command: ["python3", "scripts/transcribe.py"],
            model: "moonshine/base"
        )

        #expect(runtime == .moonshine)
    }

    @Test
    func factoryBuildsMoonshineEngineWhenMoonshineRuntimeIsDetected() {
        let engine = ASREngineFactory.makeProcessEngine(
            command: ["python3", "scripts/moonshine_transcribe.py"],
            model: "medium-streaming-en"
        )

        #expect(engine is MoonshineProcessASREngine)
    }

    @Test
    func factoryBuildsGenericEngineWhenGenericRuntimeIsDetected() {
        let engine = ASREngineFactory.makeProcessEngine(
            command: ["python3", "scripts/transcribe_generic.py"],
            model: "qwen3-asr-1.7b"
        )

        #expect(engine is GenericProcessASREngine)
    }

    @Test
    func configuredGenericCommandDoesNotChangeNonHFCommand() {
        let configured = ASREngineFactory.configuredGenericCommand(
            command: ["python3", "scripts/transcribe_generic.py"]
        )

        #expect(configured == ["python3", "scripts/transcribe_generic.py"])
    }

    @Test
    func configuredGenericCommandIsIdempotentForServerFlag() {
        let configured = ASREngineFactory.configuredGenericCommand(
            command: ["python3", "scripts/hf_asr_transcribe.py", "--server"]
        )

        #expect(configured == ["python3", "scripts/hf_asr_transcribe.py", "--server"])
    }
}
