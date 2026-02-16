# 2026-02-16 Phase 4 Global Hotkey Daemon

## Objective
Enable push-to-talk dictation from anywhere by running a background process with a real global hotkey listener.

## Scope
- Implement real global hotkey listener in `HotkeyController`.
- Add hotkey-to-session bridge to forward press/release events to `SessionOrchestrator`.
- Add `--hotkey-daemon` mode in preview CLI for background usage.

## Non-Goals
- Polished menu bar UX.
- Full hotkey customization UI.

## Steps
1. Added failing tests for bridge event forwarding lifecycle.
2. Implemented bridge and event-handling protocol.
3. Implemented global hotkey registration on macOS.
4. Added daemon CLI mode and docs for background run.
5. Ran tests and daemon startup smoke check.

## Verification Commands
- `swift test`
- `swift run DictationPreviewCLI --hotkey-daemon --moonshine-python "$(pwd)/.venv/bin/python3"`

## Verification Results
- `swift test` passed (22 tests).
- `swift run DictationPreviewCLI --hotkey-daemon --moonshine-python "$(pwd)/.venv/bin/python3"` reached:
  - `hotkey_daemon=running shortcut=ctrl+option+space`

## Outcome
- Global hotkey listener implemented via `HotkeyController` (Carbon registration).
- Press/release events are bridged to session events with `HotkeySessionBridge`.
- CLI daemon mode supports system-wide push-to-talk flow and background-friendly invocation.

## Residual Risks
- Global hotkey may conflict with local OS/user shortcuts.
- Background process permissions can still affect insertion behavior depending on target app.
