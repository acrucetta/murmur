#!/usr/bin/env python3
"""
Transcribe a WAV file using local Moonshine ONNX runtime.

Usage:
  python3 scripts/moonshine_transcribe.py /path/to/audio.wav --model moonshine/tiny
"""

import argparse
import pathlib
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe WAV with Moonshine ONNX.")
    parser.add_argument("wav_path", help="Path to a WAV file.")
    parser.add_argument("--model", default="moonshine/tiny", help="Moonshine model id.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    wav_path = pathlib.Path(args.wav_path)
    if not wav_path.exists():
        print(f"ERROR: WAV file not found: {wav_path}", file=sys.stderr)
        return 2

    try:
        import moonshine_onnx
    except ImportError:
        print(
            "ERROR: missing moonshine_onnx package. Install with: pip install useful-moonshine-onnx",
            file=sys.stderr,
        )
        return 2

    try:
        result = moonshine_onnx.transcribe(str(wav_path), args.model)
    except Exception as exc:  # pragma: no cover - runtime path
        print(f"ERROR: moonshine transcription failed: {exc}", file=sys.stderr)
        return 1

    if isinstance(result, (list, tuple)):
        text = " ".join(str(item).strip() for item in result if str(item).strip())
    else:
        text = str(result).strip()

    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
