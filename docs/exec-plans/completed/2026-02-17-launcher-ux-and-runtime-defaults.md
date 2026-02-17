# 2026-02-17 Launcher UX and Runtime Defaults

## Objective
Reduce local run friction so Murmur can be launched/stopped like a normal local utility, without repeatedly passing Python/script paths.

## Scope
- Add runtime path resolver for Moonshine python/script defaults.
- Wire resolver into menu bar app and preview CLI argument parsing.
- Add launcher script for `run/start/stop/status/logs`.
- Add top-level CLI entrypoint (`./murmur`) and optional global install command.
- Update user-facing docs to reflect new flow.

## Non-Goals
- Signed macOS `.app` bundle packaging.
- Auto-start at login via LaunchAgent.
- In-app settings UI for runtime paths.

## Steps
1. Added failing unit tests for runtime path resolution behavior.
2. Implemented `RuntimePathResolver` in core infra.
3. Wired resolver into `MurmurMenuBarApp` and `DictationPreviewCLI` defaults.
4. Added `scripts/murmur` launcher for foreground/background control.
5. Added `./murmur` wrapper and `install/uninstall/doctor` launcher commands.
6. Updated README and Moonshine setup doc with new commands and env overrides.

## Verification Commands
- `swift test`
- `swift build`
- `bash -n scripts/murmur`
- `bash -n murmur`
- `./murmur doctor`
- `~/.local/bin/murmur status`

## Verification Results
- `swift test` passed (`43` tests).
- `swift build` passed.
- `bash -n scripts/murmur` passed.
- `bash -n murmur` passed.
- `./murmur doctor` returned resolved repo/python/script values.
- `~/.local/bin/murmur status` returned `murmur not running` (expected when not started).

## Outcome
- Default run commands now work without manually passing `--moonshine-python` in common local setups.
- `murmur` CLI now supports local and global usage (`./murmur ...` and `murmur ...` after install).
- Docs updated so the recommended path is a single command (`./murmur run`).

## Residual Risks
- Launcher does not yet install as a login item or signed app bundle.
- If neither virtualenv nor `python3` is available, runtime still fails at startup.
