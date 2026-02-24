#!/usr/bin/env python3
"""Generic Hugging Face ASR transcription bridge for Murmur."""

from __future__ import annotations

import argparse
import pathlib
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe WAV with a Hugging Face ASR model.")
    parser.add_argument("wav_path", help="Path to a WAV file.")
    parser.add_argument("--model", required=True, help="Hugging Face model id or local model path.")
    parser.add_argument(
        "--trust-remote-code",
        action="store_true",
        help="Allow custom remote model code during load.",
    )
    return parser.parse_args()


def extract_text(result: object) -> str:
    if isinstance(result, dict):
        text = result.get("text", "")
        return str(text).strip()

    if isinstance(result, list):
        parts: list[str] = []
        for item in result:
            if isinstance(item, dict):
                text = str(item.get("text", "")).strip()
            else:
                text = str(item).strip()
            if text:
                parts.append(text)
        return " ".join(parts).strip()

    return str(result).strip()


def main() -> int:
    args = parse_args()
    wav_path = pathlib.Path(args.wav_path)
    if not wav_path.exists():
        print(f"ERROR: WAV file not found: {wav_path}", file=sys.stderr)
        return 2

    try:
        from transformers import pipeline
    except ImportError as exc:  # pragma: no cover - runtime guard
        print(f"ERROR: missing transformers dependency: {exc}", file=sys.stderr)
        return 2

    trust_remote_code = args.trust_remote_code or ("qwen" in args.model.lower())
    pipeline_kwargs = {
        "task": "automatic-speech-recognition",
        "model": args.model,
        "trust_remote_code": trust_remote_code,
    }

    try:
        asr = pipeline(device_map="auto", **pipeline_kwargs)
    except TypeError:
        # Older transformers builds may not support device_map here.
        asr = pipeline(**pipeline_kwargs)

    try:
        result = asr(str(wav_path))
    except Exception as exc:  # pragma: no cover - runtime path
        print(f"ERROR: huggingface transcription failed: {exc}", file=sys.stderr)
        return 1

    text = extract_text(result)
    if not text:
        print("ERROR: huggingface transcription failed: empty transcription", file=sys.stderr)
        return 1

    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
