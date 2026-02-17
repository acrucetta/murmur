# Murmur

Local-first macOS dictation MVP.

Press a global hotkey, speak, release, and insert transcript text into the focused field with no cloud dependency in the runtime path.

## Current Status

Implemented:
- Global push-to-talk hotkeys (`Ctrl+Shift+Space`, backup `Ctrl+Shift+D`).
- Local Moonshine transcription path via Python bridge.
- Cross-app insertion with Accessibility primary path + clipboard fallback.
- Menu bar app scaffold with live state and error indicators.
- Deterministic text cleanup and latency metrics in logs.

In progress:
- Hardening for reliability/perf targets from the MVP spec.

## Quick Start

### 1) Python environment (for Moonshine bridge)

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install moonshine-voice useful-moonshine-onnx
python -m moonshine_voice.download --language en
```

### 2) Build and run tests

```bash
swift build
swift test
```

### 3) Run menu bar app (recommended MVP flow)

```bash
./murmur run
```

What you get:
- Menu bar icon.
- Global hotkey dictation.
- Status menu: state, backend, last error, partial transcript.
- Default model: `medium-streaming-en` via `moonshine_voice`.
- Fallback backend: `moonshine_onnx` if `moonshine_voice` is unavailable.

### 4) Background control commands (start/stop/logs)

```bash
./murmur start
./murmur status
./murmur logs
./murmur stop
```

Optional global install (so you can run `murmur` from anywhere):

```bash
./murmur install
murmur status
```

## Run Modes

### Menu bar app

```bash
./murmur run
```

Equivalent direct command (now auto-resolves `.venv` Python if present):

```bash
swift run MurmurMenuBarApp
```

### Hotkey daemon CLI

```bash
swift run DictationPreviewCLI --hotkey-daemon
```

### Live mic preview (press Enter to start/stop)

```bash
swift run DictationPreviewCLI --moonshine-live
```

Behavior:
- Speech is captured while listening.
- Final text is inserted once on stop/release after cleanup.
- No live text is injected into the target field while you speak.

### WAV transcription preview

```bash
swift run DictationPreviewCLI --moonshine-wav /absolute/path/to/audio.wav
```

### Simulation path (no mic/model)

```bash
swift run DictationPreviewCLI --simulate "hello world from murmur"
```

## Hotkeys

- Primary: `Ctrl + Shift + Space`
- Backup: `Ctrl + Shift + D`

## Architecture Snapshot

```text
HotkeyController
   -> SessionOrchestrator (state machine)
      -> PermissionManager
      -> AudioCapture -> ASREngine (Moonshine bridge)
      -> TextPostProcessor
      -> FocusedFieldWriter (AX primary, clipboard fallback)
      -> StatusUI (menu bar + lightweight state)
```

`SessionOrchestrator` owns cross-module workflow. Modules communicate through typed events/contracts.

## Logs and Diagnostics

Common metrics/events:
- `hotkey_daemon=running ...`
- `hotkey_event=pressed|released`
- `state=listening|finalizing|inserting|idle`
- `metric release_to_final_ms=<n>`
- `metric release_to_insert_ms=<n>`

Menu bar startup diagnostics:
- `metric menu_button_configured ...`
- `metric menu_bar_diagnostics status_item=true ...`

Launcher logs:
- `/tmp/murmur-menubar.log`
- `/tmp/murmur-menubar.pid`

## Permissions Checklist (macOS)

Enable for your terminal/app runner:
- Microphone
- Accessibility
- Input Monitoring
- Screen Recording (only if you use screenshot tooling)

## Project Layout

```text
Sources/
  DictationAppCore/
  DictationPreviewCLI/
  MurmurMenuBarApp/
Tests/
docs/
  product-specs/
  exec-plans/
  agents/
```

## Documentation Map

- Product spec: `docs/product-specs/macos-local-dictation-mvp.md`
- Moonshine setup: `docs/product-specs/moonshine-local-setup.md`
- Docs index: `docs/index.md`
- Agent guide: `docs/agents/README.md`
- Architecture ASCII: `docs/agents/ARCHITECTURE_ASCII.md`

## Development Workflow

- Spec-driven for non-trivial changes.
- TDD default: `red -> green -> refactor`.
- Keep diffs narrow and module boundaries strict.
- Always report what was verified and what was not run.
