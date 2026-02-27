# 2026-02-27 ASR Model Dropdown Menu

## Problem Statement
ASR model selection is not exposed as a direct clickable picker in the menu bar settings surface. Users should be able to choose ASR models from a curated list without manual text entry.

## Scope
- Add a dedicated ASR model row to the menu bar settings menu.
- Populate ASR choices from `CLIConfigOptionCatalog` curated ASR models.
- Persist ASR model choice to the existing config file (`asr_model.txt`).
- Keep menu snapshot/action contracts in sync with new ASR selection state.

## Non-goals
- Rebuild runtime engine instances when ASR model changes.
- Add a custom/free-text ASR model entry UI in menu bar (CLI wizard remains the custom-entry path).
- Change ASR runtime inference or script resolution behavior.

## Constraints
- Keep diffs narrow and local to menu bar settings wiring.
- Preserve existing config compatibility (`~/Library/Application Support/Murmur`).
- Maintain existing rewrite/microphone/pause-media behavior.

## Interfaces/Contracts Affected
- `MenuBarSettingsSnapshot`
- `MenuBarSettingsAction`
- `MenuBarController` menu rendering/actions
- `MenuBarConfigSnapshot` + `MurmurConfigStore` persistence handling

## Acceptance Criteria
1. Menu includes an `ASR Model` row with a clickable submenu of curated ASR choices.
2. Current ASR model is shown and checked in submenu.
3. Selecting a submenu ASR model persists to `asr_model.txt`.
4. Tests cover new settings contracts for ASR model snapshot/action.

## Verification Commands
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter MenuBarSettingsContractsTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter CLIConfigOptionCatalogTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift build --product MurmurMenuBarApp --disable-sandbox`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift build --product DictationPreviewCLI --disable-sandbox`

## Result Summary
- Added menu ASR settings contract fields/actions (`asrModel`, `setASRModel`) and threaded them through menu snapshot/state.
- Added a clickable `ASR Model` submenu in menu bar UI using curated choices from `CLIConfigOptionCatalog` (excluding `Custom...`).
- Added persistence handling for menu ASR selection in `MurmurConfigStore` (`asr_model.txt`).
- Added a contract test file (`MenuBarSettingsContractsTests`) covering ASR model snapshot/action.
- Verification outcomes:
  - `swift test --filter MenuBarSettingsContractsTests` (failed in environment: `no such module 'Testing'`)
  - `swift build --product MurmurMenuBarApp --disable-sandbox` (pass)
  - `swift build --product DictationPreviewCLI --disable-sandbox` (pass)
