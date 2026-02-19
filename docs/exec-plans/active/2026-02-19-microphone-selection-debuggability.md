# 2026-02-19 Microphone Selection + Debuggability

## Objective
Add explicit microphone selection to Murmur runtime/config so capture failures can be isolated to a known input device instead of relying on OS default routing.

## Scope
- Add microphone device discovery and selection support in `AudioCapture`.
- Add persisted config support (`--microphone`, `--reset-microphone`) in `scripts/murmur`.
- Add runtime wiring (`--microphone`) for menu bar app + preview CLI.
- Add a discoverability command (`murmur microphones` / `DictationPreviewCLI --list-microphones`).
- Add capture-failure diagnostics so logs distinguish missing frames vs very-low input level.
- Update README command/config docs.

## Non-goals
- Automatic fallback between multiple microphones at runtime.
- UI-level real-time level meters per-device in menu bar app.
- Changes to ASR post-processing behavior.

## Constraints
- Preserve default behavior when no microphone is configured.
- Keep diffs narrow; do not rework core orchestrator flow.
- Keep selection deterministic by matching microphone UID first, then name.

## Implementation Steps
1. Add `AudioInputDevice` catalog + selector logic with CoreAudio-backed discovery.
2. Extend `AudioCapture` to apply preferred input device before engine start.
3. Add unit tests for microphone resolution semantics.
4. Add CLI plumbing (`--microphone`) in app args + launcher script config.
5. Add `--list-microphones` preview mode and `murmur microphones` command.
6. Update README configuration and troubleshooting guidance.

## Verification
- `bash -n scripts/murmur`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox`
- `./.build/debug/DictationPreviewCLI --list-microphones`

## Result Summary
- Added persisted microphone selection support and explicit runtime binding.
- Added CLI device listing for quick diagnostics.
- Added tests for selection behavior (`AudioInputDeviceSelectorTests`).
- Added finalize-failure capture diagnostics (`captured_frames`, `captured_avg_rms`, `captured_peak_rms`, `captured_quality`) for faster mic debugging.
- Added fallback behavior when a configured microphone is no longer present (logs warning, uses system default).
- Removed custom/manual microphone entry from the interactive config wizard; selection is now discovered devices + system default reset.
- Full Swift test suite passes in this environment.
