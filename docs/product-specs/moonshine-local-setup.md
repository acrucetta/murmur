# Moonshine Local Setup

Use this to enable local WAV transcription in the preview CLI.

## 1) Install local Python dependency
```bash
pip install moonshine-voice useful-moonshine-onnx
python -m moonshine_voice.download --language en
```
If Homebrew Python blocks global installs (`externally-managed-environment`), use a venv:
```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install moonshine-voice useful-moonshine-onnx
python -m moonshine_voice.download --language en
```

## 2) Run Moonshine preview against a WAV file
```bash
swift run DictationPreviewCLI --moonshine-wav /absolute/path/to/audio.wav
```

## 3) Run Moonshine preview from live microphone capture
```bash
swift run DictationPreviewCLI --moonshine-live
```
Flow:
- Focus a target text box before starting (Notes, Slack, browser textarea, VS Code editor).
- Press Enter to start capture.
- Speak.
- Press Enter to stop and finalize transcription. The CLI attempts focused-field insertion using AX primary and clipboard fallback.
- During capture, the CLI prints periodic `input_meter` lines and a final `capture_summary`.

## 4) Run as global hotkey daemon (background-friendly)
```bash
swift run DictationPreviewCLI --hotkey-daemon
```

Default hotkeys:
- `Ctrl + Shift + Space` (primary)
- `Ctrl + Shift + D` (backup)

Background example:
```bash
nohup swift run DictationPreviewCLI --hotkey-daemon > /tmp/murmur-daemon.log 2>&1 &
```
Lower-latency restart example (skips `swift run` build step):
```bash
swift build
nohup ./.build/debug/DictationPreviewCLI --hotkey-daemon > /tmp/murmur-daemon.log 2>&1 &
```

Optional flags:
- `--moonshine-python /path/to/python3`
- `--moonshine-script /path/to/scripts/moonshine_transcribe.py`
- `--model medium-streaming-en` (default)
- `MURMUR_MOONSHINE_PYTHON=/path/to/python3` (env override for all run modes)
- `MURMUR_MOONSHINE_SCRIPT=/path/to/script.py` (env override for all run modes)

Default resolver order for python:
1. `--moonshine-python`
2. `MURMUR_MOONSHINE_PYTHON`
3. `$VIRTUAL_ENV/bin/python3`
4. `./.venv/bin/python3`
5. `python3`

Advanced script flags (passed via `--moonshine-script` custom wrapper):
- `--backend auto|voice|onnx` (default `auto`)
- `--voice-model-path /absolute/path/to/model_dir`
- `--voice-model-arch medium-streaming|small-streaming|...`
- `--max-tokens-per-second <int>`
- `--vad-threshold <float>`

## Notes
- This path is fully local/offline after model assets are available on disk.
- `scripts/moonshine_transcribe.py` tries `moonshine_voice` first, then falls back to `moonshine_onnx`.
- Live mode quality depends on local microphone/input settings and speaking during capture window.

## Troubleshooting daemon/hotkeys
Check logs in another terminal:
```bash
tail -f /tmp/murmur-daemon.log
```
Expected startup lines:
- `hotkey_daemon=running shortcuts=ctrl+shift+space|ctrl+shift+d`
- `hotkey_backend=carbon+event_tap` (or `carbon` / `event_tap` depending on permissions/runtime)
- `hint=focus_any_textbox_hold_ctrl_shift_space_or_ctrl_shift_d_speak_release_to_insert`

Expected hotkey activity:
- `hotkey_event=pressed`
- `state=listening`
- `hotkey_event=released`
- `state=finalizing`

If startup fails, check for:
- `error=hotkey_start_failed ... eventHotKeyExistsErr` (another process already owns this shortcut).
- `error=hotkey_start_failed ... eventInternalErr` (environment issue; test in a normal interactive terminal session).

## 5) Run as menu bar app (logo + live state)
```bash
./murmur run
```
What you should see:
- A Murmur icon in the macOS menu bar.
- Menu lines for current state, active hotkey backend, last error, and partial transcript.
- `Quit Murmur` action from the menu.

The same hotkeys are active:
- `Ctrl + Shift + Space`
- `Ctrl + Shift + D`

Launcher shortcuts:
```bash
./murmur run      # foreground
./murmur start
./murmur status
./murmur logs
./murmur stop
./murmur history
./murmur history-path
```

`run` stays attached to your terminal.
`start` runs in the background and writes logs to `/tmp/murmur-menubar.log`.

Transcript history files are stored at:
- `~/Library/Application Support/Murmur/transcriptions/`

Optional global install for `murmur` command anywhere:
```bash
./murmur install
murmur doctor
```
