#!/usr/bin/env python3
"""Generic Hugging Face/MLX ASR transcription bridge for Murmur."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import platform
import sys
from typing import Callable, TextIO


def is_apple_silicon() -> bool:
    return platform.system() == "Darwin" and platform.machine() == "arm64"


def requires_qwen_asr_runtime(model_id: str) -> bool:
    normalized = model_id.strip().lower()
    return "qwen3-asr" in normalized or "qwen3_asr" in normalized


def should_use_mlx_runtime(model_id: str) -> bool:
    return is_apple_silicon() and requires_qwen_asr_runtime(model_id)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe WAV with a Hugging Face/MLX ASR model.")
    parser.add_argument("wav_path", nargs="?", help="Path to a WAV file.")
    parser.add_argument("--model", required=True, help="Hugging Face model id or local model path.")
    parser.add_argument(
        "--trust-remote-code",
        action="store_true",
        help="Allow custom remote model code during load.",
    )
    parser.add_argument(
        "--server",
        action="store_true",
        help="Run persistent NDJSON worker mode on stdin/stdout.",
    )
    return parser.parse_args()


def extract_text(result: object) -> str:
    if hasattr(result, "text"):
        text = getattr(result, "text", "")
        return str(text).strip()

    if isinstance(result, dict):
        text = result.get("text", "")
        return str(text).strip()

    if isinstance(result, list):
        parts: list[str] = []
        for item in result:
            if hasattr(item, "text"):
                text = str(getattr(item, "text", "")).strip()
            elif isinstance(item, dict):
                text = str(item.get("text", "")).strip()
            else:
                text = str(item).strip()
            if text:
                parts.append(text)
        return " ".join(parts).strip()

    return str(result).strip()


def transcribe_with_qwen_asr(wav_path: pathlib.Path, model_id: str) -> str:
    try:
        import torch
        from qwen_asr import Qwen3ASRModel
    except ImportError as exc:  # pragma: no cover - runtime guard
        raise RuntimeError(f"missing qwen-asr dependency: {exc}") from exc

    if torch.cuda.is_available():
        device_map = "cuda:0"
        dtype = torch.bfloat16
    else:
        device_map = "cpu"
        dtype = torch.float32

    asr_model = Qwen3ASRModel.from_pretrained(
        model_id,
        dtype=dtype,
        device_map=device_map,
    )
    result = asr_model.transcribe(audio=str(wav_path))
    return extract_text(result)


def transcribe_with_mlx_audio(wav_path: pathlib.Path, model_id: str) -> str:
    transcriber = load_mlx_transcriber(model_id)
    return transcriber(wav_path)


def transcribe_with_transformers(
    wav_path: pathlib.Path, model_id: str, force_trust_remote_code: bool
) -> str:
    transcriber = load_transformers_transcriber(model_id, force_trust_remote_code)
    return transcriber(wav_path)


def load_mlx_transcriber(model_id: str) -> Callable[[pathlib.Path], str]:
    try:
        from mlx_audio import stt
        from mlx_audio.stt import utils as stt_utils
    except ImportError as exc:  # pragma: no cover - runtime guard
        raise RuntimeError(f"missing mlx-audio dependency: {exc}") from exc

    if hasattr(stt, "load_model"):
        loaded_model = stt.load_model(model_id)
    elif hasattr(stt, "load"):  # pragma: no cover - compatibility branch
        loaded_model = stt.load(model_id)
    else:  # pragma: no cover - defensive branch
        raise RuntimeError("mlx_audio.stt.load_model API unavailable")

    def _transcribe(wav_path: pathlib.Path) -> str:
        audio = stt_utils.load_audio(str(wav_path), sr=16_000)
        if hasattr(loaded_model, "generate"):
            result = loaded_model.generate(audio)
        else:  # pragma: no cover - defensive branch
            raise RuntimeError("mlx STT model does not expose generate()")
        return extract_text(result)

    return _transcribe


def load_qwen_asr_transcriber(model_id: str) -> Callable[[pathlib.Path], str]:
    try:
        import torch
        from qwen_asr import Qwen3ASRModel
    except ImportError as exc:  # pragma: no cover - runtime guard
        raise RuntimeError(f"missing qwen-asr dependency: {exc}") from exc

    if torch.cuda.is_available():
        device_map = "cuda:0"
        dtype = torch.bfloat16
    else:
        device_map = "cpu"
        dtype = torch.float32

    asr_model = Qwen3ASRModel.from_pretrained(
        model_id,
        dtype=dtype,
        device_map=device_map,
    )

    def _transcribe(wav_path: pathlib.Path) -> str:
        result = asr_model.transcribe(audio=str(wav_path))
        return extract_text(result)

    return _transcribe


def load_transformers_transcriber(
    model_id: str,
    force_trust_remote_code: bool,
) -> Callable[[pathlib.Path], str]:
    try:
        from transformers import pipeline
    except ImportError as exc:  # pragma: no cover - runtime guard
        raise RuntimeError(f"missing transformers dependency: {exc}") from exc

    trust_remote_code = force_trust_remote_code or ("qwen" in model_id.lower())
    pipeline_kwargs = {
        "task": "automatic-speech-recognition",
        "model": model_id,
        "trust_remote_code": trust_remote_code,
    }

    try:
        asr = pipeline(device_map="auto", **pipeline_kwargs)
    except TypeError:
        asr = pipeline(**pipeline_kwargs)

    def _transcribe(wav_path: pathlib.Path) -> str:
        result = asr(str(wav_path))
        return extract_text(result)

    return _transcribe


def load_transcriber(model_id: str, trust_remote_code: bool) -> Callable[[pathlib.Path], str]:
    if should_use_mlx_runtime(model_id):
        return load_mlx_transcriber(model_id)
    if requires_qwen_asr_runtime(model_id):
        return load_qwen_asr_transcriber(model_id)
    return load_transformers_transcriber(model_id, trust_remote_code)


def write_message(output_stream: TextIO, payload: dict[str, object]) -> None:
    output_stream.write(json.dumps(payload, ensure_ascii=False) + "\n")
    output_stream.flush()


def run_server(
    model_id: str,
    trust_remote_code: bool,
    input_stream: TextIO = sys.stdin,
    output_stream: TextIO = sys.stdout,
) -> int:
    try:
        transcriber = load_transcriber(model_id, trust_remote_code=trust_remote_code)
    except Exception as exc:
        print(f"ERROR: failed to initialize transcriber: {exc}", file=sys.stderr)
        return 1

    write_message(
        output_stream,
        {"type": "ready", "model": model_id, "pid": os.getpid()},
    )

    for raw_line in input_stream:
        line = raw_line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError as exc:
            write_message(output_stream, {"type": "result", "id": "unknown", "ok": False, "error": f"invalid json: {exc}"})
            continue

        request_type = str(request.get("type", "")).strip().lower()
        if request_type == "shutdown":
            return 0

        if request_type != "transcribe":
            write_message(
                output_stream,
                {
                    "type": "result",
                    "id": str(request.get("id", "unknown")),
                    "ok": False,
                    "error": f"unsupported request type: {request_type}",
                },
            )
            continue

        request_id = str(request.get("id", "")).strip() or "unknown"
        wav_path = pathlib.Path(str(request.get("wav_path", "")).strip())
        if not wav_path.exists():
            write_message(
                output_stream,
                {"type": "result", "id": request_id, "ok": False, "error": f"WAV file not found: {wav_path}"},
            )
            continue

        try:
            text = transcriber(wav_path)
            if not text:
                raise RuntimeError("empty transcription")
            write_message(output_stream, {"type": "result", "id": request_id, "ok": True, "text": text})
        except Exception as exc:
            write_message(output_stream, {"type": "result", "id": request_id, "ok": False, "error": str(exc)})

    return 0


def run_oneshot(wav_path: pathlib.Path, model_id: str, trust_remote_code: bool) -> int:
    try:
        transcriber = load_transcriber(model_id, trust_remote_code=trust_remote_code)
        text = transcriber(wav_path)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:  # pragma: no cover - runtime path
        print(f"ERROR: huggingface transcription failed: {exc}", file=sys.stderr)
        return 1

    if not text:
        print("ERROR: huggingface transcription failed: empty transcription", file=sys.stderr)
        return 1

    print(text)
    return 0


def main() -> int:
    args = parse_args()
    if args.server:
        return run_server(model_id=args.model, trust_remote_code=args.trust_remote_code)

    if not args.wav_path:
        print("ERROR: wav_path is required unless --server is set", file=sys.stderr)
        return 2

    wav_path = pathlib.Path(args.wav_path)
    if not wav_path.exists():
        print(f"ERROR: WAV file not found: {wav_path}", file=sys.stderr)
        return 2

    return run_oneshot(
        wav_path=wav_path,
        model_id=args.model,
        trust_remote_code=args.trust_remote_code,
    )


if __name__ == "__main__":
    raise SystemExit(main())
