# Murmur

Local-first macOS dictation with push-to-talk, local ASR (Moonshine), and reliable text insertion.

![Murmur AI art](docs/assets/jazz-murmur-ai.svg)

`Murmur` is designed to work immediately without cloud setup:
- Default rewrite mode is `literal` (no LLM token required).
- Optional `smart` rewrite uses OpenRouter when configured.
- Runtime path stays local-first and falls back safely on failure.

## Quick Start

```bash
git clone git@github.com:acrucetta/murmur.git
cd murmur
./murmur install
murmur run
```

Usage flow:
1. Focus any text field.
2. Hold the hotkey (`ctrl+shift+space` by default).
3. Speak, then release.
4. Murmur inserts cleaned text.

Background mode:

```bash
murmur start
murmur logs
murmur stop
```

## Requirements

- macOS 13+
- Swift toolchain (Xcode Command Line Tools is enough)
- Python 3 (for Moonshine runtime setup)
- Internet access on first install (dependencies + model download)

## Installation

Recommended:

```bash
./murmur install
```

This installer:
- creates/reuses `.venv`
- installs Moonshine Python dependencies
- downloads the English Moonshine model
- builds `MurmurMenuBarApp`
- installs global `murmur` command

Useful options:

```bash
./murmur install --python /absolute/path/to/python3
./murmur install --skip-model-download
./murmur install --link-only
```

If `murmur` is not in `PATH` after install, add `~/.local/bin` to `PATH`.

## Rewrite Modes

`Murmur` supports two rewrite modes:

- `literal` (default): deterministic cleanup only, no LLM rewrite.
- `smart`: deterministic cleanup + optional OpenRouter rewrite.

Default behavior:
- If you do nothing, Murmur runs in `literal` mode.
- No API key is required for the default path.

Enable smart mode:

```bash
export OPENROUTER_API_KEY="<your-token>"
export MURMUR_REWRITE_MODE="smart"
export MURMUR_OPENROUTER_MODEL="mistralai/mistral-small-3.1-24b-instruct"
murmur run
```

One-off mode override:

```bash
murmur run --rewrite-mode literal
murmur run --rewrite-mode smart --openrouter-model mistralai/mistral-small-3.1-24b-instruct
```

## Configuration

Interactive wizard:

```bash
murmur config
```

Scriptable updates:

```bash
murmur config set --shortcut "ctrl+option+space"
murmur config set --reset-shortcut
murmur config set --mode smart --model mistralai/mistral-small-3.1-24b-instruct
murmur config set --api-key "<token>"
murmur config set --clear-api-key
```

Config precedence:
1. CLI flags (`--rewrite-mode`, `--openrouter-model`, etc.)
2. Environment variables (`MURMUR_*`, `OPENROUTER_API_KEY`)
3. Config files in `~/Library/Application Support/Murmur`
4. Built-in defaults (`literal` mode, default model id)

## Logging and Grep

Background log file:

```bash
/tmp/murmur-menubar.log
```

Log format is structured and grep-friendly:

```text
ts=2026-02-18T12:34:56.789Z level=info metric release_to_insert_ms=183
ts=2026-02-18T12:34:57.111Z level=info metric smart_rewrite_usage model=... turn_total_tokens=...
```

Common filters:

```bash
rg "metric release_to_(final|insert)_ms=" /tmp/murmur-menubar.log
rg "metric smart_rewrite_" /tmp/murmur-menubar.log
rg "level=info warning=" /tmp/murmur-menubar.log
```

## CLI Reference

```bash
murmur run [--model <id>] [--rewrite-mode <literal|smart>] [--openrouter-model <id>]
murmur start [--model <id>] [--rewrite-mode <literal|smart>] [--openrouter-model <id>]
murmur stop
murmur logs
murmur config
murmur config set [--shortcut <combo>] [--reset-shortcut] [--mode literal|smart] [--model <id>] [--api-key <token>] [--clear-api-key]
murmur doctor
murmur install [--python <python3>] [--skip-model-download] [--link-only]
murmur uninstall
```

Help:

```bash
murmur --h
murmur config --h
```

## Development

Build and test:

```bash
swift build
swift test
```

Useful code paths:
- Core orchestrator: `Sources/DictationAppCore/Core/SessionOrchestrator.swift`
- Rewrite module: `Sources/DictationAppCore/Modules/Rewrite/`
- Menu bar app entry: `Sources/MurmurMenuBarApp/main.swift`
- Launcher script: `scripts/murmur`

## Troubleshooting

- Hotkey does nothing:
  - Verify `Microphone`, `Accessibility`, and `Input Monitoring` permissions.
- ASR fails:
  - Run `murmur doctor`.
  - Confirm Python path + Moonshine script resolution.
- Smart rewrite not applying:
  - Confirm mode is `smart`.
  - Confirm API key is present (`murmur doctor` shows key presence/source).
- Insertion fails in secure fields:
  - This is expected in protected input contexts.

## Architecture

```text
User Hotkey
  -> HotkeyController
  -> SessionOrchestrator
     -> PermissionManager
     -> AudioCapture
     -> ASREngine (Moonshine bridge)
     -> TextPostProcessorV2
     -> Optional OpenRouterTranscriptRewriter (smart mode)
     -> FocusedFieldWriter (Accessibility direct + clipboard fallback)
     -> TranscriptHistoryStore (local files)
     -> StatusUI (menu bar)
```

## Docs

- Docs index: `docs/index.md`
- Product specs: `docs/product-specs/`
- Active/completed plans: `docs/exec-plans/`
