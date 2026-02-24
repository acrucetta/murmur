# 2026-02-24 Pluggable ASR Provider Runtime

## Problem Statement
Murmur previously hardcoded Moonshine runtime wiring, then exposed a provider toggle (`moonshine` vs `generic`) that made config UX confusing. We need model-first runtime selection where the model id is the only user-facing selector and runtime backend is inferred automatically.

## Scope
- Add an ASR runtime contract in core runtime.
- Keep Moonshine runtime as default behavior for existing defaults.
- Add a generic process-script runtime for plug-and-play integration experiments.
- Expose model selection in app/CLI launch paths and `murmur config set`.
- Remove explicit provider flags/env plumbing from user-facing runtime paths.
- Update docs for model-first runtime options.

## Non-goals
- Ship built-in Qwen/MLX backend implementation in this change.
- Replace Moonshine Python bridge internals.
- Add benchmark automation UI/command.

## Constraints
- Preserve existing `SessionOrchestrator` boundary ownership.
- Backward compatibility for existing Moonshine flows and launch commands.
- Keep runtime local/offline defaults for Moonshine.

## Interfaces/Contracts Affected
- `DictationAppCore` ASR module (provider abstraction + factory).
- `MurmurMenuBarApp` argument parsing/runtime wiring.
- `DictationPreviewCLI` argument parsing/runtime wiring.
- `scripts/murmur` config and launch argument passing.
- `README.md` runtime/config usage examples.

## Acceptance Criteria
1. Murmur instantiates ASR runtime from model/script metadata (Moonshine default plus generic script runtime).
2. Model can be set in launcher config and passed through run/start; provider toggle is not exposed.
3. Existing Moonshine defaults continue to work without new flags.
4. Tests cover runtime inference/factory behavior and generic process engine command invocation.

## Verification Commands
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter ASREngineFactoryTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter GenericProcessASREngineTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter MoonshineProcessASREngineTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift build --product MurmurMenuBarApp --disable-sandbox`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift build --product DictationPreviewCLI --disable-sandbox`

## Risks/Notes
- Generic provider relies on a script contract (`<script> <wav_path> --model <id>`), so adapter scripts may still be required for model-specific runtimes.
- Generic Hugging Face models may require larger local caches and Python dependencies before first run.

## Result Summary
- Added pluggable ASR runtime contract (`moonshine` default + `generic` process runtime).
- Added `ASREngineFactory`, `GenericProcessASREngine`, and orchestrator-agnostic engine error reporting.
- Removed explicit provider parsing/wiring in menu bar app args, preview CLI args, and `murmur` launcher runtime path.
- Runtime backend is now inferred from model/script metadata while model remains the only user-facing selector.
- Added ASR model setup helpers (`scripts/asr_model_catalog.py`, `scripts/asr_model_setup.py`, `scripts/hf_asr_transcribe.py`) and `murmur asr <list|use|current>` workflow.
- Updated docs for model-first ASR selection (`--asr-model`) and standardized ASR runtime overrides (`--asr-python`, `--asr-script`).
- Verification outcomes:
  - `swift test --filter ASREngineFactoryTests` (pass)
  - `swift test --filter GenericProcessASREngineTests` (pass)
  - `swift test --filter RuntimePathResolverTests` (pass)
  - `swift test --filter MoonshineProcessASREngineTests` (pass)
  - `swift test --filter SessionOrchestratorTests` (pass)
  - `swift test` (pass)
  - `swift build --product MurmurMenuBarApp` (pass)
  - `swift build --product DictationPreviewCLI` (pass)
  - `bash -n scripts/murmur` + `./murmur doctor` smoke (pass)
  - `python3 -m unittest discover -s scripts/tests` (pass)
  - `./murmur asr list` + isolated `asr use qwen3-asr-1.7b` smoke (pass)
