# 2026-02-16 Phase 2 Live Moonshine Loop

## Objective
Add a fast local live loop so Moonshine can be exercised from microphone capture without waiting for full app integration.

## Scope
- Wire `AudioCapture` to emit live `AudioFrame` values.
- Add `--moonshine-live` mode in `DictationPreviewCLI` (press enter to start/stop).
- Add integration test that verifies Moonshine backend finalization flows through orchestrator to insertion.

## Non-Goals
- Full menubar app UX integration.
- Global hotkey handling in production path.
- Advanced partial transcript streaming from Moonshine backend.

## Steps
1. Added failing tests for `AudioCapture` frame callback and Moonshine backend finalize-to-insert flow.
2. Implemented live frame capture in `AudioCapture` using `AVAudioEngine` tap + PCM mono conversion.
3. Implemented `--moonshine-live` mode in CLI (press enter to start/stop).
4. Ran `swift test` and CLI smoke checks for simulated and live paths.

## Verification Commands
- `swift test`
- `swift run DictationPreviewCLI --simulate "live moonshine loop"`
- `swift run DictationPreviewCLI --moonshine-live --moonshine-python "$(pwd)/.venv/bin/python3"`

## Verification Results
- `swift test` passed (16 tests).
- `swift run DictationPreviewCLI --simulate "live moonshine loop"` passed.
- `swift run DictationPreviewCLI --moonshine-live --moonshine-python "$(pwd)/.venv/bin/python3"` passed startup/start-stop flow and reached finalize path; local smoke run produced `emptyTranscription` due no captured speech in this environment.

## Outcome
- Live microphone frames can now flow through `SessionOrchestrator` to Moonshine backend in preview mode.
- Fast iteration path now supports both:
  - simulated transcript loop
  - real mic start/stop loop
- Integration tests cover Moonshine finalize-to-insert orchestration behavior.

## Residual Risks
- Live transcription quality depends on local mic permissions and speaking during capture.
- Partial transcript streaming from Moonshine is still not implemented.
