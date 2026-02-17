# 2026-02-17 Shortcut CLI Config and README Refresh

## Objective
Add a simple CLI-managed hotkey configuration flow and refresh README for faster onboarding.

## Scope
- Parse configurable shortcut identifiers in hotkey module.
- Wire configurable primary shortcut into menu bar and daemon runtimes.
- Add `murmur shortcut get|set|reset` commands with local config persistence.
- Refresh README structure (install, quick start, features, architecture) with a playful visual touch.

## Non-Goals
- In-app GUI shortcut editor.
- Runtime hotkey change without restart.
- Multi-profile shortcut sets.

## Steps
1. Added failing tests for shortcut identifier parsing.
2. Implemented `HotkeyShortcut.parse(identifier:)` with modifier/key validation.
3. Added `--shortcut` support in `MurmurMenuBarApp` and `DictationPreviewCLI --hotkey-daemon`.
4. Added launcher config persistence (`shortcut.txt`) and `shortcut get|set|reset` commands.
5. Updated README and setup docs for new commands + friendlier onboarding flow.

## Verification Commands
- `swift test`
- `bash -n scripts/murmur`
- `bash -n murmur`
- `./murmur shortcut get`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-test ./murmur shortcut set "ctrl+option+space"`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-test ./murmur shortcut get`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-test ./murmur shortcut reset`

## Verification Results
- `swift test` passed (`49` tests).
- shell syntax checks passed for both launcher scripts.
- shortcut CLI commands returned expected values and persisted in `/tmp` config override.

## Outcome
- Shortcut is now configurable from CLI without code changes.
- Runtime continues to keep backup shortcut enabled.
- README is clearer for first-time users and contributors.

## Residual Risks
- Shortcut validation is syntactic; runtime conflicts with OS/app shortcuts are still possible.
- Shortcut changes require process restart.
