# 2026-02-16 Phase 2 Moonshine Bridge

## Objective
Wire a real Moonshine integration point into the MVP architecture while preserving fast local iteration loops.

## Scope
- Add `MoonshineProcessASREngine` backend to `Modules/ASR`.
- Update orchestrator to accept synchronous final transcript from ASR finalize.
- Add CLI mode to run Moonshine transcription on a local WAV file.
- Add local Moonshine bridge script for Python runtime execution.

## Verification
- `swift test` (pass, 14 tests)
- `swift run DictationPreviewCLI --simulate "phase two moonshine wiring"` (pass)
- `swift run DictationPreviewCLI --moonshine-wav /tmp/does-not-exist.wav` (pass: actionable error path)

## Outcome
- ASR protocol now supports synchronous finalization and engine error signaling.
- `SessionOrchestrator` can finalize insertion directly from ASR on shortcut release.
- Moonshine backend can run fully local transcription through:
  - `scripts/moonshine_transcribe.py`
  - `MoonshineProcessASREngine`
  - `DictationPreviewCLI --moonshine-wav ...`

## Residual
- Local environment still needs Moonshine package + model files installed.
- End-to-end microphone capture -> Moonshine path is not wired yet (WAV file path currently used for quick validation).
