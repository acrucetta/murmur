# Murmur 🎙️✨

Local-first macOS dictation powered by [Moonshine Voice](https://github.com/moonshine-ai/moonshine?tab=readme-ov-file).

Hold a global hotkey, speak, release, and Murmur inserts cleaned text into the focused field. No cloud calls in the runtime path.

```text
   ( speak )   ──▶   🫧 Murmur   ──▶   ( text appears )
```

## Features

- Global push-to-talk hotkey with configurable primary shortcut.
- Local ASR via Moonshine (`moonshine_voice` primary, `moonshine_onnx` fallback).
- Cross-app insertion (Accessibility direct write + clipboard fallback).
- Disfluency-aware cleanup (basic stutter/repair handling).
- Menu bar runtime + simple CLI launcher.
- Local transcript history on disk.

## Install

### 1) Clone + Python env

```bash
git clone git@github.com:acrucetta/murmur.git
cd murmur
python3 -m venv .venv
source .venv/bin/activate
python -m pip install moonshine-voice useful-moonshine-onnx
python -m moonshine_voice.download --language en
```

### 2) Build and test

```bash
swift build
swift test
```

### 3) Install CLI command globally (optional)

```bash
./murmur install
```

After this, use `murmur ...` from anywhere.

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
5. Insert into focused app field.
6. Result + transcript line is logged locally.

## Architecture

```text
User Hotkey
  -> HotkeyController
  -> SessionOrchestrator (state machine)
     -> PermissionManager
     -> AudioCapture
     -> ASREngine (Moonshine Python bridge)
     -> TextPostProcessorV2
     -> FocusedFieldWriter
        -> Accessibility direct
        -> Clipboard paste fallback
     -> TranscriptHistoryStore (local files)
     -> StatusUI (menu bar)
```

## CLI Reference

```bash
murmur run
murmur start|stop|restart|status|logs
murmur shortcut get|set [combo]|reset
murmur history [lines]
murmur history-path
murmur doctor
murmur install|uninstall
```

## Troubleshooting

- If hotkey does nothing, verify macOS permissions for the launching app:
  - Microphone
  - Accessibility
  - Input Monitoring
- If ASR fails, run `murmur doctor` and verify `python` + script paths.
- If insertion fails in secure fields, expected behavior is safe failure.

## Development Notes

- Product spec: `docs/product-specs/macos-local-dictation-mvp.md`
- Moonshine setup details: `docs/product-specs/moonshine-local-setup.md`
- Agent docs index: `docs/index.md`
