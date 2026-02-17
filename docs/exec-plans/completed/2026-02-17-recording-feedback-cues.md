# 2026-02-17 Recording Feedback Cues

## Objective
Add clear user feedback when recording starts and stops, similar to push-to-talk tools.

## Scope
- Add a feedback contract in app core.
- Trigger feedback at recording start and recording stop transitions in `SessionOrchestrator`.
- Implement concrete feedback in menu bar app (sound + haptic) using bundled custom cue assets.
- Add tests for feedback behavior and asset loading.

## Non-Goals
- Customizable feedback sound packs.
- Per-app or per-shortcut feedback settings UI.
- Visual-only alternatives in this change.

## Steps
1. Added failing tests for feedback trigger behavior in `SessionOrchestratorTests`.
2. Added `FeedbackPresenting` and `NoopFeedbackPresenter` in core.
3. Wired orchestrator to call feedback on:
   - transition into `listening` (recording start)
   - transition into `finalizing` (recording stop)
4. Added bundled custom cue assets (`feedback_start.wav`, `feedback_stop.wav`) in `DictationAppCore` resources.
5. Added menu bar runtime feedback presenter using bundled cues + AppKit haptics.
6. Added `FeedbackSoundAssetTests` to verify assets exist and load as `NSSound`.
7. Updated README feature list.

## Verification Commands
- `swift test --filter SessionOrchestratorTests`
- `swift test --filter FeedbackSoundAssetTests`
- `swift test`
- `swift build`

## Verification Results
- `swift test --filter SessionOrchestratorTests` passed.
- `swift test --filter FeedbackSoundAssetTests` passed.
- `swift test` passed (`54` tests).
- `swift build` passed.

## Outcome
- Users now get immediate feedback when recording begins and ends.
- Feedback behavior is centralized in orchestrator transitions and enabled for menu bar runtime with bundled gentle cues.

## Residual Risks
- Haptic behavior depends on host hardware support and macOS runtime conditions.
