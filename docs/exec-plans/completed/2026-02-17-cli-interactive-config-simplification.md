# 2026-02-17 CLI Interactive Config Simplification

## Problem Statement
The launcher CLI config logic in `scripts/murmur` has become difficult to maintain due to duplicated interactive and non-interactive branches. The current interactive path only partially covers user setup and does not provide a fast, guided end-to-end configuration flow.

## Scope
- In:
  - Introduce a single guided `murmur config` wizard that configures shortcut + rewrite settings in one pass.
  - Keep non-interactive config updates (`murmur config set --...`) for scripting/automation.
  - Refactor shell logic to reduce branching duplication and centralize config writes.
  - Update README/product docs for the new interactive flow.
- Out:
  - Full migration of launcher from bash to another language.
  - New third-party CLI runtime dependency.
  - Runtime hot-reload of settings without restart.

## Constraints
- Performance:
  - Interactive flow should finish in under 30 seconds for typical setup.
- Reliability:
  - Existing install/run/start/stop/history/doctor commands remain unchanged.
  - Non-interactive config flags remain backward compatible.
- Privacy/Security:
  - API key prompts remain silent and stored with restricted file permissions.
- Compatibility:
  - Continue supporting `MURMUR_CONFIG_DIR` override and existing config files.

## Interfaces/Contracts Affected
- `scripts/murmur`
- `README.md`
- `docs/product-specs/smart-rewrite-openrouter.md`
- `docs/product-specs/moonshine-local-setup.md`

## Acceptance Criteria
1. `murmur config` launches an interactive wizard covering shortcut, rewrite mode, model, and API key handling.
2. `murmur config get` output keys remain stable for existing diagnostics.
3. `murmur config set` with flags still works non-interactively.
4. The script provides clear restart notes when runtime is already running.

## Verification Commands
- `bash -n scripts/murmur`
- `bash -n murmur`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config get`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config set --mode literal --model test/model --api-key test-key`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config get`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config set --clear-api-key`
- `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur shortcut get`

## Ordered Implementation Steps
1. Add/adjust behavior checks for the desired quick config flow semantics where possible in non-interactive mode.
2. Refactor config/shortcut command internals to shared helpers and implement the guided wizard.
3. Keep command compatibility aliases and stable diagnostic output.
4. Update README/product docs to describe the quick interactive flow.
5. Run verification commands and capture results.

## Risks/Blockers
- Fully testing TTY-dependent prompts is limited in automated checks.
- Prompt flow complexity can regress if not consolidated in shared helpers.

## Result Summary (to fill at completion)
- Status: implemented and verified locally
- Commands run:
  - `bash -n scripts/murmur` (pass)
  - `bash -n murmur` (pass)
  - `swift build --product DictationPreviewCLI` (pass)
  - `swift test --filter HotkeyShortcutPresentationTests` (pass)
  - `swift test` (pass, `61` tests)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config get` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config set --mode literal --model test/model --api-key test-key --shortcut ctrl+option+space` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config set --clear-api-key --reset-shortcut` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur shortcut get` (pass)
  - `printf '' | MURMUR_CONFIG_DIR=/tmp/murmur-cli-refactor ./murmur config` (expected fail with exit `2`, pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-cli-wizard ./murmur config` via PTY scripted input (pass interactive smoke)
- Residual risks:
  - The interactive wizard UI is prompt-based (clean terminal flow) rather than a full-screen TUI framework.
  - Capturing keyboard shortcuts still depends on local Input Monitoring permissions.
