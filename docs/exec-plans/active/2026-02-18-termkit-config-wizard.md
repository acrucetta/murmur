# 2026-02-18 TermKit Config Wizard

## Problem Statement
`murmur config` currently uses a prompt-driven wizard with free-text entry for model/hotkey fields. Users requested a more delightful Bubble Tea-like experience with dropdown-style model selection, easier hotkey adjustments, and simpler API-key entry.

## Scope
- In:
  - Replace `DictationPreviewCLI --config-wizard` prompt UI with TermKit UI.
  - Provide list/dropdown style selection for OpenRouter model IDs.
  - Provide easy hotkey adjustment flow (preset list + custom entry).
  - Provide clear API key set/replace/clear flow in the same wizard.
  - Preserve existing persisted config files and shell command contracts.
- Out:
  - Rewriting non-interactive `murmur config set` behavior.
  - Changing runtime dictation pipeline or menu bar app behavior.
  - Introducing cloud dependency in runtime path.

## Constraints
- Performance:
  - Wizard startup should stay within normal CLI startup expectations.
- Reliability:
  - Wizard must never corrupt existing config; writes remain atomic.
  - Cancellation must avoid partial writes.
- Privacy/Security:
  - API key entry must be masked in UI and stored with restrictive permissions.
- Compatibility:
  - Existing `MURMUR_CONFIG_DIR` behavior and config filenames remain unchanged.

## Interfaces/Contracts Affected
- `Package.swift` (new dependency)
- `Sources/DictationPreviewCLI/main.swift` (wizard implementation)
- `Sources/DictationPreviewCLI/TermKitConfigWizard.swift` (new TermKit wizard)
- `Sources/DictationAppCore/Infra/CLIConfigOptionCatalog.swift` (shared option lists)
- `Tests/DictationAppCoreTests/CLIConfigOptionCatalogTests.swift` (catalog coverage)
- `scripts/murmur` (contract validation only, no behavior change expected)
- `README.md` (interactive wizard behavior docs)
- `docs/product-specs/smart-rewrite-openrouter.md` (interactive setup docs)

## Acceptance Criteria
1. `murmur config` launches a TermKit-driven wizard UI.
2. OpenRouter model choice is selectable from a list instead of requiring manual typing.
3. Hotkey can be changed quickly from presets and custom entry.
4. API key can be set/replaced/cleared from the wizard.
5. Persisted config outputs remain compatible with existing runtime.

## Verification Commands
- `swift build --product DictationPreviewCLI`
- `swift test`
- `bash -n scripts/murmur`
- `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config set --shortcut ctrl+option+space --mode smart --model test/model --api-key test-key`
- `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config get`
- `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config` (interactive smoke, manual)

## Risks/Blockers
- TermKit event loop exits process on stop; exit semantics must remain clear for shell callers.
- Some terminal environments may render differently; keep fallback-safe text labels.

## Result Summary
- Status: implemented and verified locally
- Commands run:
  - `swift test --filter TermKitConfigWizardOptionsTests` (expected fail, red; pre-implementation)
  - `swift test --filter CLIConfigOptionCatalogTests` (pass, green)
  - `swift build --product DictationPreviewCLI` (pass)
  - `swift test` (pass, 64 tests)
  - `bash -n scripts/murmur` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config set --shortcut ctrl+option+space --mode smart --model test/model --api-key test-key` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config set --clear-api-key --reset-shortcut` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config get` (pass)
  - `swift run DictationPreviewCLI --config-wizard ...` via PTY scripted navigation to cancel (pass interactive smoke; exits with status `1`)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-termkit ./murmur config` via PTY scripted navigation (interactive smoke reached TermKit UI)
  - `./murmur --h` (pass; cleaned help output/alias path)
  - `./murmur config --h` (pass)
  - `MURMUR_CONFIG_DIR=/tmp/murmur-termkit-pty3 ./murmur config` via PTY scripted navigation:
    - open hotkey selector -> choose `Custom...` -> custom hotkey dialog opens (pass)
    - open model selector -> choose `Custom...` -> custom model dialog opens (pass)
- Residual risks:
  - Color rendering fidelity depends on terminal color support (16-color fallback can vary by terminal).
  - `./murmur config` PTY cancellation path displayed cancel output; shell-level status behavior should be rechecked in an end-to-end human run because scripted PTY wrappers can mask status propagation.
  - Custom follow-up dialogs intentionally use a short defer (`0.2s`) after selector close to avoid close/open jitter in nested modal flows.
