#!/usr/bin/env python3
"""Transcribe WAV audio with local Moonshine runtimes.

Default behavior prefers ``moonshine_voice`` (latest streaming-capable model
family) and falls back to ``moonshine_onnx`` if needed.
"""

import argparse
import pathlib
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe WAV with Moonshine Voice/ONNX.")
    parser.add_argument("wav_path", help="Path to a WAV file.")
    parser.add_argument("--model", default="medium-streaming-en", help="Model id hint.")
    parser.add_argument(
        "--backend",
        default="auto",
        choices=["auto", "voice", "onnx"],
        help="Transcription backend preference.",
    )
    parser.add_argument("--language", default="en", help="Language code for voice backend.")
    parser.add_argument(
        "--voice-model-path",
        default=None,
        help="Optional explicit model directory for moonshine_voice.",
    )
    parser.add_argument(
        "--voice-model-arch",
        default=None,
        choices=[
            "tiny",
            "base",
            "tiny-streaming",
            "base-streaming",
            "small-streaming",
            "medium-streaming",
        ],
        help="Optional explicit model arch for moonshine_voice.",
    )
    parser.add_argument(
        "--max-tokens-per-second",
        type=int,
        default=None,
        help="Optional moonshine_voice decoder constraint.",
    )
    parser.add_argument("--vad-threshold", type=float, default=None)
    parser.add_argument("--vad-window-duration", type=float, default=None)
    parser.add_argument("--vad-hop-size", type=float, default=None)
    parser.add_argument("--vad-max-segment-duration", type=float, default=None)
    return parser.parse_args()


def _infer_voice_arch_and_language(
    model_hint: str, language: str, explicit_arch: str | None
) -> tuple[str, str]:
    if explicit_arch:
        return explicit_arch, language

    model_key = model_hint.strip().lower().split("/")[-1]
    known_arches = {
        "tiny",
        "base",
        "tiny-streaming",
        "base-streaming",
        "small-streaming",
        "medium-streaming",
    }

    if model_key in known_arches:
        return model_key, language

    if model_key.endswith("-en"):
        without_lang = model_key[: -len("-en")]
        if without_lang in known_arches:
            return without_lang, "en"

    return "medium-streaming", language


def _infer_onnx_model(model_hint: str) -> str:
    model_key = model_hint.strip().lower().split("/")[-1]
    if model_key.endswith("-en"):
        model_key = model_key[: -len("-en")]

    if "tiny" in model_key:
        return "moonshine/tiny"
    if "base" in model_key:
        return "moonshine/base"
    # moonshine_onnx currently supports tiny/base families only.
    return "moonshine/base"


def _transcribe_with_moonshine_voice(args: argparse.Namespace) -> str:
    from moonshine_voice import string_to_model_arch
    from moonshine_voice.download import (
        download_model_from_info,
        find_model_info,
        get_components_for_model_info,
    )
    from moonshine_voice.download_file import get_cache_dir
    from moonshine_voice.transcriber import Transcriber
    from moonshine_voice.utils import load_wav_file

    arch_name, language = _infer_voice_arch_and_language(
        model_hint=args.model,
        language=args.language,
        explicit_arch=args.voice_model_arch,
    )
    model_arch = string_to_model_arch(arch_name)

    if args.voice_model_path:
        model_path = str(pathlib.Path(args.voice_model_path).expanduser())
    else:
        model_info = find_model_info(language=language, model_arch=model_arch)
        cache_dir = pathlib.Path(get_cache_dir())
        model_root = cache_dir / model_info["download_url"].replace("https://", "")
        components = get_components_for_model_info(model_info)
        if all((model_root / component).exists() for component in components):
            model_path = str(model_root)
            model_arch = model_info["model_arch"]
        else:
            model_path, model_arch = download_model_from_info(model_info)

    options: dict[str, int | float] = {}
    if args.max_tokens_per_second is not None:
        options["max_tokens_per_second"] = args.max_tokens_per_second
    if args.vad_threshold is not None:
        options["vad_threshold"] = args.vad_threshold
    if args.vad_window_duration is not None:
        options["vad_window_duration"] = args.vad_window_duration
    if args.vad_hop_size is not None:
        options["vad_hop_size"] = args.vad_hop_size
    if args.vad_max_segment_duration is not None:
        options["vad_max_segment_duration"] = args.vad_max_segment_duration

    audio_data, sample_rate = load_wav_file(args.wav_path)
    with Transcriber(
        model_path=model_path,
        model_arch=model_arch,
        options=options if options else None,
    ) as transcriber:
        transcript = transcriber.transcribe_without_streaming(audio_data, sample_rate)

    text = " ".join(line.text.strip() for line in transcript.lines if line.text and line.text.strip())
    return text.strip()


def _transcribe_with_moonshine_onnx(args: argparse.Namespace) -> str:
    import moonshine_onnx

    onnx_model = _infer_onnx_model(args.model)
    result = moonshine_onnx.transcribe(str(args.wav_path), onnx_model)
    if isinstance(result, (list, tuple)):
        text = " ".join(str(item).strip() for item in result if str(item).strip())
    else:
        text = str(result).strip()
    return text


def main() -> int:
    args = parse_args()
    wav_path = pathlib.Path(args.wav_path)
    if not wav_path.exists():
        print(f"ERROR: WAV file not found: {wav_path}", file=sys.stderr)
        return 2

    backends = ["voice", "onnx"] if args.backend == "auto" else [args.backend]
    errors: list[str] = []

    for backend in backends:
        try:
            if backend == "voice":
                text = _transcribe_with_moonshine_voice(args)
            else:
                text = _transcribe_with_moonshine_onnx(args)

            if not text:
                errors.append(f"{backend}: empty transcription")
                continue

            print(text)
            return 0
        except ImportError as exc:
            errors.append(f"{backend}: missing dependency ({exc})")
        except Exception as exc:  # pragma: no cover - runtime path
            errors.append(f"{backend}: {exc}")

    details = "; ".join(errors) if errors else "unknown backend error"
    print(f"ERROR: moonshine transcription failed: {details}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
