# 2026-02-18 Pause Media While Dictating

## Problem Statement
Users want an option to suppress background audio while dictating so spoken input is clearer and less distracting. The requested behavior is to pause active music playback while push-to-talk recording is active.

## Scope
- In:
  - Add a persisted setting for pausing media during recording.
  - Wire the setting through launcher config and menu bar runtime startup.
  - Pause playback on recording start and resume on recording stop (best-effort).
  - Keep orchestration logic testable in `DictationAppCore`.
  - Update user-facing docs for the new option.
- Out:
  - Per-app granular policies (e.g., pause only Spotify but not Music).
  - Browser-tab specific media control.
  - New UI surfaces in the menu bar popover.

## Constraints
- Performance:
  - Recording start/stop latency impact should be minimal; media control runs best-effort.
- Reliability:
  - Recording pipeline must continue even if media pause/resume fails.
  - Default runtime behavior stays unchanged unless setting is enabled.
- Privacy/Security:
  - No cloud dependency; local macOS APIs/scripting only.
  - Do not log secret config values.
- Compatibility:
  - Existing config files and command-line usage remain backward compatible.

## Interfaces/Contracts Affected
- `Sources/DictationAppCore/Core/SessionOrchestrator.swift`
- `Sources/DictationAppCore/Modules/*` (new recording media control protocol)
- `Tests/DictationAppCoreTests/SessionOrchestratorTests.swift`
- `Tests/DictationAppCoreTests/TestDoubles.swift`
- `Sources/MurmurMenuBarApp/main.swift`
- `Sources/DictationPreviewCLI/TermKitConfigWizard.swift`
- `scripts/murmur`
- `README.md`

## Acceptance Criteria
1. A new config setting exists to enable/disable pausing media while recording.
2. When enabled, recording start triggers media pause and recording stop triggers resume (best-effort).
3. When disabled (default), media control is not invoked.
4. Existing dictation behavior and tests remain green.

## Verification Commands
- `swift test --filter SessionOrchestratorTests`
- `swift test`
- `swift build --product MurmurMenuBarApp`
- `bash -n scripts/murmur`
- `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur config set --pause-media true`
- `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur config set --pause-media false`
- `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur doctor`
- `./murmur --h`
- `./murmur config --h`

## Risks/Blockers
- Apple event control of third-party media apps can be blocked by system automation permissions.
- Best-effort pause/resume may not cover every audio source.

## Result Summary
- Status: implemented and verified locally
- Commands run:
  - `swift test --filter SessionOrchestratorTests` (expected fail, red; before implementation)
  - `swift test --filter SessionOrchestratorTests` (pass, green)
  - `swift test` (pass, 86 tests)
  - `swift build --product MurmurMenuBarApp` (pass)
  - `bash -n scripts/murmur` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur config set --pause-media true` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur config set --pause-media false` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur config set --pause-media maybe` (expected fail, validation pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-media ./murmur doctor` (pass)
  - `./murmur --h` (pass)
  - `./murmur config --h` (pass)
- Residual risks:
  - Media control is best-effort and currently targets Music + Spotify; browser/player-specific sessions are not guaranteed.
  - First-time automation prompts/denials for app control can prevent pause/resume without impacting dictation flow.
