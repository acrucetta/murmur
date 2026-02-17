# Murmur 🎙️✨

Local-first macOS dictation powered by [Moonshine Voice](https://github.com/moonshine-ai/moonshine?tab=readme-ov-file).

![Jazz Murmur AI art](docs/assets/jazz-murmur-ai.svg)

Hold a global hotkey, speak, release, and Murmur inserts cleaned text into the focused field. Default runtime path is local-only; optional smart rewrite can use OpenRouter.

```text
   ( speak )   ──▶   🫧 Murmur   ──▶   ( text appears )
```

## Features

- Global push-to-talk hotkey with configurable primary shortcut.
- Local ASR via Moonshine (`moonshine_voice` primary, `moonshine_onnx` fallback).
- Cross-app insertion (Accessibility direct write + clipboard fallback).
- Disfluency-aware cleanup (basic stutter/repair handling).
- Optional smart rewrite mode via OpenRouter (safe fallback on transport/API failure).
- Recording start/stop feedback cues (sound + haptic in menu bar app runtime).
- Menu bar runtime + simple CLI launcher.
- Local transcript history on disk.

## Install

### 1) Clone

```bash
git clone git@github.com:acrucetta/murmur.git
cd murmur
```

### 2) One-command install (recommended)

```bash
./murmur install
```

This does everything needed to run:
- creates/reuses `.venv`
- installs Moonshine Python dependencies
- downloads the English Moonshine model
- builds the Murmur app binary
- installs global `murmur` command

### 3) Run

```bash
murmur run
```

Optional local-only setup (no global command):

```bash
./murmur setup
./murmur run
```

### 4) Development verification (optional)

```bash
swift build
swift test
```

If you used local-only setup, use `./murmur ...` for commands shown below.

### Installer Notes

- `./murmur install` is safe to rerun. It reuses `.venv` and only refreshes what is needed.
- First install needs internet access for package/model download.
- If your Python executable is non-standard, use `./murmur install --python /absolute/path/to/python3`.
- If `murmur` is not found after install, add `~/.local/bin` to `PATH` or run `./murmur install --link-only`.
- On first launch, macOS may ask for `Microphone`, `Accessibility`, and `Input Monitoring` permissions.

## Quick Start

Run in foreground:

```bash
murmur run
```

Run in background:

```bash
murmur start
murmur status
murmur logs
murmur stop
```

## Rewrite Modes

`Murmur` supports two rewrite modes:

- `smart` (default): deterministic cleanup + optional OpenRouter polish if API key is configured.
- `literal`: minimal deterministic cleanup only, no LLM rewrite.

By default, if no OpenRouter API key is set, smart mode still runs local deterministic cleanup and inserts immediately.

Enable smart mode with OpenRouter:

```bash
export OPENROUTER_API_KEY="<your-token>"
export MURMUR_REWRITE_MODE="smart"
export MURMUR_OPENROUTER_MODEL="mistralai/mistral-small-3.1-24b-instruct"
murmur run
```

Switch to literal mode:

```bash
export MURMUR_REWRITE_MODE="literal"
murmur run
```

One-off override (without changing env):

```bash
murmur run --rewrite-mode literal
murmur run --rewrite-mode smart --openrouter-model mistralai/mistral-small-3.1-24b-instruct
```

Configure rewrite mode from CLI (interactive):

```bash
murmur config
```

This opens a guided config wizard where you can:
- keep/capture/type/reset the primary shortcut
- choose `literal` or `smart`
- set model id (smart mode)
- enter/replace/clear your OpenRouter API key
- review all changes before apply

If shortcut capture cannot complete (for example permissions or terminal-host issues), the wizard offers immediate manual-entry fallback.

Script-friendly updates are still supported:

```bash
murmur config set --shortcut "ctrl+option+space"
murmur config set --reset-shortcut
murmur config set --mode smart --model mistralai/mistral-small-3.1-24b-instruct
murmur config set --api-key "<token>"
murmur config set --clear-api-key
```

## Configure Shortcut

Show current shortcut:

```bash
murmur shortcut get
```

Set a new primary shortcut:

```bash
murmur shortcut set
```

Or set it directly by identifier:

```bash
murmur shortcut set "ctrl+option+space"
```

Reset to default:

```bash
murmur shortcut reset
```

Notes:
- Primary default: `ctrl+shift+space`
- Backup remains enabled: `ctrl+shift+d`
- `murmur shortcut set` starts a key listener and prompts for confirmation.
- Restart Murmur after changing shortcut.

## Transcript History

View where transcripts are stored:

```bash
murmur history-path
```

Show recent transcript lines:

```bash
murmur history
murmur history 200
```

Default location:
- `~/Library/Application Support/Murmur/transcriptions/`

## How It Works

1. Global hotkey press starts local audio capture.
2. Audio frames stream to Moonshine.
3. On release, ASR finalizes once.
4. Text is post-processed (cleanup, punctuation, casing).
5. Optional smart rewrite runs (OpenRouter) and falls back to local text on API/transport error.
6. Insert into focused app field.
7. Result + transcript line is logged locally.

## Architecture

```text
User Hotkey
  -> HotkeyController
  -> SessionOrchestrator (state machine)
     -> PermissionManager
     -> AudioCapture
     -> ASREngine (Moonshine Python bridge)
     -> TextPostProcessorV2
     -> Optional OpenRouterTranscriptRewriter (smart mode only)
     -> FocusedFieldWriter
        -> Accessibility direct
        -> Clipboard paste fallback
     -> TranscriptHistoryStore (local files)
     -> StatusUI (menu bar)
```

## CLI Reference

```bash
murmur run
murmur run --rewrite-mode literal|smart [--openrouter-model <id>]
murmur setup [--python <python3>] [--skip-model-download] [--global]
murmur start|stop|restart|status|logs
murmur config [wizard|get|set ...]
murmur config set [--shortcut <combo>] [--reset-shortcut] [--mode literal|smart] [--model <id>] [--api-key <token>] [--clear-api-key]
murmur shortcut get|set [combo]|reset
murmur history [lines]
murmur history-path
murmur doctor
murmur install [--python <python3>] [--skip-model-download] [--link-only]
murmur uninstall
```

## Troubleshooting

- If hotkey does nothing, verify macOS permissions for the launching app:
  - Microphone
  - Accessibility
  - Input Monitoring
- If ASR fails, run `murmur doctor` and verify `python` + script paths.
- If smart rewrite is enabled, run `murmur doctor` to confirm rewrite mode/model and API key presence.
- If insertion fails in secure fields, expected behavior is safe failure.

## Development Notes

- Product spec: `docs/product-specs/macos-local-dictation-mvp.md`
- Moonshine setup details: `docs/product-specs/moonshine-local-setup.md`
- Agent docs index: `docs/index.md`
