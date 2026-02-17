# macOS local dictation MVP spec

Canonical product spec for this repository.

## Problem
Build a local-only macOS dictation tool:
- Press global shortcut.
- Speak.
- Release shortcut.
- Insert transcript into the currently focused text box.
- No cloud dependency in the runtime path.

## Scope and non-goals
In scope:
- Push-to-talk global shortcut.
- On-device speech-to-text using Moonshine.
- Cross-app text insertion.
- Minimal cleanup (spacing, capitalization, punctuation).
- Basic status UI (menu bar + tiny state indicator).
- Recording start/stop user feedback cues in menu bar runtime (sound + haptic).

Non-goals (MVP):
- Rewriting/paraphrasing with LLM.
- Account system, sync, analytics, remote API.
- Advanced NLP features (intent, diarization, commands beyond basic).
- iOS, Windows, Linux support.

## Design principles
- Deep modules, shallow interfaces.
- Each module owns one hard problem.
- Hide complexity behind stable contracts.
- Keep orchestration dumb and explicit.
- Prefer specific code paths over premature generalization.
- One fallback path per boundary.

## Constraints
- Runtime: offline.
- Latency target: final insert <= 900 ms after key release on Apple Silicon baseline.
- Reliability target: >= 95% successful insertions on common apps.
- Privacy target: do not persist raw audio by default.

## Module boundaries
- `HotkeyController`: global push-to-talk detection.
- `PermissionManager`: mic/accessibility/input-monitoring state and prompting.
- `AudioCapture`: PCM capture pipeline.
- `ASREngine`: Moonshine partial/final transcript production.
- `TextPostProcessor`: deterministic cleanup rules.
- `FocusedFieldWriter`: accessibility insert + clipboard fallback.
- `SessionOrchestrator`: state machine and cross-module workflow.
- `StatusUI`: menu bar and lightweight state feedback.
- `FeedbackPresenter`: recording start/stop feedback contract; concrete menu bar implementation plays cues.

## Contracts
- Events: `ShortcutPressed`, `ShortcutReleased`, `AudioFrame`, `PartialTranscript`, `FinalTranscript`, `InsertResult`.
- Feedback events: `recording_started`, `recording_stopped`.
- Insertion methods: `accessibility_direct`, `clipboard_paste`.
- Failure codes: `permission_denied`, `no_focused_field`, `secure_input_blocked`, `engine_error`, `insertion_failed`.

## State machine
- `Idle -> Listening` on `ShortcutPressed` and permission success.
- `Listening -> Finalizing` on `ShortcutReleased`.
- `Finalizing -> Inserting` on `FinalTranscript`.
- `Inserting -> Idle` on `InsertSuccess`.
- `Inserting -> Error` on `InsertFailure`.
- `Error -> Idle` after reset.

## Acceptance criteria
1. Holding shortcut starts recording within 100 ms.
2. Releasing shortcut inserts transcript in <= 900 ms median.
3. AX insertion failure falls back to clipboard in <= 1200 ms median.
4. Missing permissions show actionable prompts without crash.
5. App remains responsive across 100 sessions.
6. In menu bar runtime, recording start/stop cues fire once per press/release cycle when permissions are granted.
