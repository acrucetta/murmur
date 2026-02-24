# 2026-02-19 Local-Only Moonshine Runtime

## Objective
Ensure Murmur runtime ASR is strictly local/offline after install by default, with no Hugging Face network fetches during transcription.

## Scope
- Make `scripts/moonshine_transcribe.py` offline-by-default.
- Prevent runtime model downloads when offline mode is active.
- Pass offline mode from `MoonshineProcessASREngine` command invocation.
- Update docs to clarify local-only runtime behavior and network requirements.

## Non-goals
- Rework Moonshine model packaging/distribution format.
- Add a full model integrity verifier command.

## Constraints
- Preserve existing hotkey/menu bar and CLI transcription flow.
- Keep explicit opt-in path for network fetches for debugging/recovery.
- Keep diffs narrow and focused on ASR runtime path.

## Implementation Steps
1. Add `--offline` default + `--allow-network` override to `scripts/moonshine_transcribe.py`.
2. In offline mode, block voice model download path and fail with actionable missing-assets error.
3. Set `HF_HUB_OFFLINE` / `TRANSFORMERS_OFFLINE` in offline mode.
4. In `auto` backend mode, avoid ONNX fallback when offline to prevent implicit downloads.
5. Pass `--offline` from `MoonshineProcessASREngine`.
6. Update tests/docs and verify.

## Verification
- `python3 scripts/moonshine_transcribe.py --help`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter MoonshineProcessASREngineTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter SessionOrchestratorTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift build --product MurmurMenuBarApp --disable-sandbox`

## Risks/Notes
- Offline mode now surfaces missing local model assets as explicit failures instead of downloading automatically.
- If users skipped model download at install, transcription will fail until local assets are present.
