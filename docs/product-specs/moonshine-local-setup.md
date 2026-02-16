# Moonshine Local Setup

Use this to enable local WAV transcription in the preview CLI.

## 1) Install local Python dependency
```bash
pip install useful-moonshine-onnx
```

## 2) Run Moonshine preview against a WAV file
```bash
swift run DictationPreviewCLI --moonshine-wav /absolute/path/to/audio.wav --model moonshine/tiny
```

## 3) Run Moonshine preview from live microphone capture
```bash
swift run DictationPreviewCLI --moonshine-live --moonshine-python "$(pwd)/.venv/bin/python3"
```
Flow:
- Focus a target text box before starting (Notes, Slack, browser textarea, VS Code editor).
- Press Enter to start capture.
- Speak.
- Press Enter to stop and finalize transcription. The CLI attempts focused-field insertion using AX primary and clipboard fallback.
- During capture, the CLI prints periodic `input_meter` lines and a final `capture_summary`.

Optional flags:
- `--moonshine-python /path/to/python3`
- `--moonshine-script /path/to/scripts/moonshine_transcribe.py`

## Notes
- This path is fully local/offline after model assets are available on disk.
- Live mode quality depends on local microphone/input settings and speaking during capture window.
