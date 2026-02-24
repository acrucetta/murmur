# 2026-02-21 Startup Latency and UI Smoothing

## Problem Statement
Press-to-recording feel is not seamless. Recent runtime logs show high startup latency (`shortcut_to_audio_start_ms`, `shortcut_to_first_audio_frame_ms`) and repeated preferred-microphone errors, making the first part of dictation feel delayed.

## Scope
- In:
  - Improve perceived startup responsiveness in menu bar runtime feedback path.
  - Reduce repeat startup overhead from preferred microphone resolution failures.
  - Add startup-path timing metrics to isolate where startup time is spent.
- Out:
  - Changing model/provider for smart rewrite.
  - Broad ASR pipeline refactors.

## Constraints
- Performance: preserve/advance the `<=100ms` recording-start UX target from product spec where possible.
- Reliability: no regression to existing insertion flow and state transitions.
- Privacy/Security: no cloud/runtime data behavior changes.
- Compatibility: keep existing CLI/config behavior and microphone config formats.

## Interfaces/Contracts Affected
- `Sources/DictationAppCore/Core/SessionOrchestrator.swift`
- `Sources/DictationAppCore/Modules/Audio/AudioCapture.swift`
- `Sources/MurmurMenuBarApp/main.swift`
- Tests in `Tests/DictationAppCoreTests/*`

## Acceptance Criteria
1. Startup logs include finer-grained timings to explain startup path costs.
2. Preferred microphone failures degrade gracefully to system default without repeated expensive retries each press.
3. Recording-start visual feedback is not blocked behind cue/haptic work.

## Verification Commands
- `swift test --filter SessionOrchestratorTests`
- `swift test --filter AudioCaptureTests`
- `swift test --filter FeedbackSoundAssetTests`

## Rollout/Risk Notes
- Risk: microphone hot-plug state may not be re-attempted immediately after a failure.
- Fallback: user can restart runtime or clear explicit microphone selection if behavior is unexpected.

## Result Summary
- Added startup-path metrics:
  - `shortcut_to_listening_ms`
  - `asr_start_duration_ms`
  - `audio_capture_start_duration_ms`
  - `shortcut_to_audio_start_ms`
  - `feedback_dispatch_duration_ms`
  - `shortcut_to_feedback_dispatch_ms`
  - `shortcut_to_first_audio_frame_ms`
- Added preferred-microphone fail-fast fallback behavior and actionable `AudioCaptureError` descriptions.
- Added runtime auto-clear for stale preferred microphone setting on `inputDeviceNotFound` so future launches use system default.
- Reordered menu bar feedback callback execution so visual state updates are scheduled before cue/haptic playback and preloaded cue assets on presenter init.

## Verification Outcomes
- `swift test --filter SessionOrchestratorTests` (pass)
- `swift test --filter AudioCaptureTests` (pass)
- `swift test --filter FeedbackSoundAssetTests` (pass)
- `swift build` (pass)
- Manual local runtime check attempted with:
  - `(printf '\n'; sleep 1; printf '\n') | ./.build/debug/DictationPreviewCLI --moonshine-live`
  - In this headless/sandboxed execution context AVFoundation throws a CoreAudio exception while constructing input graph, so live mic latency could not be benchmarked from this environment.
- Manual GUI runtime check (unsandboxed) with `murmur run` + synthetic shortcut press:
  - Observed `menu_settings_auto_cleared key=microphone reason=input_device_not_found ...`
  - Verified `~/Library/Application Support/Murmur/microphone.txt` was removed after the error.
