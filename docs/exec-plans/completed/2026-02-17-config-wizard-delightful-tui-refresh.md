# 2026-02-17 Config Wizard Delightful TUI Refresh

## Problem Statement
The current `murmur config` wizard is functional but too plain, and dynamic shortcut capture has reliability issues in real use. We need a more delightful terminal setup experience with robust shortcut capture.

## Scope
- In:
  - Redesign Swift config wizard UX to feel more intentional and pleasant in terminal.
  - Fix dynamic shortcut capture path used by wizard.
  - Preserve non-interactive `murmur config set` behavior and output compatibility.
  - Update docs to reflect the improved interactive experience.
- Out:
  - Full migration to Go/TypeScript CLI runtime.
  - Full-screen external TUI framework dependency requiring extra installer tooling.

## Constraints
- Performance:
  - Wizard should remain fast and not add startup delays beyond normal binary launch.
- Reliability:
  - Shortcut capture must be robust and give actionable fallback if capture fails.
  - Existing `murmur run/start/stop/...` paths remain unchanged.
- Privacy/Security:
  - API key stays silent on entry and persisted with restricted file permissions.
- Compatibility:
  - Existing config files and `MURMUR_CONFIG_DIR` overrides remain valid.

## Interfaces/Contracts Affected
- `Sources/DictationPreviewCLI/main.swift`
- `scripts/murmur`
- `README.md`
- `docs/product-specs/smart-rewrite-openrouter.md`

## Acceptance Criteria
1. `murmur config` presents a clearly improved, guided terminal UX (step framing + review + confirmation).
2. Selecting dynamic shortcut capture in wizard succeeds reliably or gives clear fallback guidance.
3. `murmur config set --...` and `murmur config get` stay compatible.
4. Verification commands pass.

## Verification Commands
- `bash -n scripts/murmur`
- `swift build --product DictationPreviewCLI`
- `swift test --filter HotkeyShortcutPresentationTests`
- `swift test`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-delight ./murmur config set --shortcut ctrl+option+space --mode smart --model test/model --api-key test-key`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-delight ./murmur config get`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-delight ./murmur config` (PTY smoke)

## Risks/Blockers
- Terminal UX polish without external framework has practical limits.
- Shortcut capture still depends on OS Input Monitoring permissions.

## Result Summary
- Status: implemented and verified locally
- Commands run:
  - `bash -n scripts/murmur` (pass)
  - `bash -n murmur` (pass)
  - `swift build --product DictationPreviewCLI` (pass)
  - `swift test --filter HotkeyShortcutPresentationTests` (pass)
  - `swift test` (pass, `61` tests)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-delight ./murmur config set --shortcut ctrl+option+space --mode smart --model test/model --api-key test-key` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-delight ./murmur config get` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-delight ./murmur config` via PTY scripted input (pass interactive smoke)
- Residual risks:
  - Dynamic shortcut capture path was refactored to subprocess capture with manual fallback, but cannot be fully automated in CI due global key-event dependency.
