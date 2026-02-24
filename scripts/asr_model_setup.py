#!/usr/bin/env python3
"""Resolve, install, and prefetch ASR models for Murmur."""

from __future__ import annotations

import argparse
import importlib
import pathlib
import subprocess
import sys

from asr_model_catalog import (
    ASRModelSpec,
    infer_moonshine_arch_and_language,
    list_catalog_entries,
    resolve_model_spec,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ASR model setup utility.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List curated model aliases.")
    list_parser.add_argument("--plain", action="store_true", help="Plain alias-only output.")

    resolve_parser = subparsers.add_parser("resolve", help="Resolve model id/alias to runtime spec.")
    resolve_parser.add_argument("--model", required=True, help="Model alias or identifier.")
    resolve_parser.add_argument("--root-dir", required=True, help="Repository root path.")

    ensure_parser = subparsers.add_parser("ensure", help="Ensure runtime dependencies and model assets.")
    ensure_parser.add_argument("--model", required=True, help="Model alias or identifier.")
    ensure_parser.add_argument("--root-dir", required=True, help="Repository root path.")
    ensure_parser.add_argument("--python", required=True, help="Python interpreter used for pip/install.")
    ensure_parser.add_argument("--skip-download", action="store_true", help="Skip model asset download.")

    return parser.parse_args()


def run_command(command: list[str]) -> None:
    subprocess.run(command, check=True)


def ensure_python_packages(python_bin: str, packages: list[str]) -> None:
    if not packages:
        return
    run_command([python_bin, "-m", "pip", "install", *packages])


def modules_available(module_names: list[str]) -> bool:
    for module_name in module_names:
        try:
            importlib.import_module(module_name)
        except Exception:
            return False
    return True


def ensure_moonshine_assets(spec: ASRModelSpec, python_bin: str, skip_download: bool) -> None:
    if not modules_available(["moonshine_voice", "moonshine_onnx"]):
        ensure_python_packages(
            python_bin,
            [
                "moonshine-voice",
                "useful-moonshine-onnx",
            ],
        )

    if skip_download:
        return

    arch, language = infer_moonshine_arch_and_language(spec.setup_model_ref)
    run_command(
        [
            python_bin,
            "-m",
            "moonshine_voice.download",
            "--language",
            language,
            "--model-arch",
            arch,
        ]
    )


def _huggingface_snapshot_download(model_id: str, local_files_only: bool) -> bool:
    module = importlib.import_module("huggingface_hub")
    snapshot_download = getattr(module, "snapshot_download")
    try:
        snapshot_download(
            repo_id=model_id,
            local_files_only=local_files_only,
            resume_download=True,
        )
        return True
    except Exception:
        return False


def ensure_huggingface_assets(spec: ASRModelSpec, python_bin: str, skip_download: bool) -> None:
    if not modules_available(
        ["transformers", "huggingface_hub", "torch", "soundfile", "librosa"]
    ):
        ensure_python_packages(
            python_bin,
            [
                "transformers>=4.45",
                "huggingface_hub>=0.24",
                "accelerate",
                "torch",
                "soundfile",
                "librosa",
                "sentencepiece",
            ],
        )

    if skip_download:
        return

    # Try local cache first to avoid unnecessary network calls.
    if _huggingface_snapshot_download(spec.setup_model_ref, local_files_only=True):
        return

    if not _huggingface_snapshot_download(spec.setup_model_ref, local_files_only=False):
        raise RuntimeError(f"failed to download Hugging Face model '{spec.setup_model_ref}'")


def emit_spec(spec: ASRModelSpec, python_bin: str) -> None:
    print(f"runtime={spec.provider}")
    # Legacy key retained for backwards compatibility with existing wrappers.
    print(f"provider={spec.provider}")
    print(f"runtime_model={spec.runtime_model}")
    print(f"runtime_script={spec.runtime_script}")
    print(f"python={python_bin}")
    print(f"setup_kind={spec.setup_kind}")
    print(f"trust_remote_code={'true' if spec.trust_remote_code else 'false'}")


def run_list(plain: bool) -> int:
    entries = list_catalog_entries()
    if plain:
        for entry in entries:
            print(entry.alias)
        return 0

    print("alias\truntime\truntime_model\tnote")
    for entry in entries:
        print(f"{entry.alias}\t{entry.provider}\t{entry.runtime_model}\t{entry.note}")
    return 0


def run_resolve(model: str, root_dir: str) -> int:
    spec = resolve_model_spec(model, root_dir=pathlib.Path(root_dir))
    emit_spec(spec, python_bin=sys.executable)
    return 0


def run_ensure(model: str, root_dir: str, python_bin: str, skip_download: bool) -> int:
    spec = resolve_model_spec(model, root_dir=pathlib.Path(root_dir))
    if spec.setup_kind == "moonshine":
        ensure_moonshine_assets(spec, python_bin=python_bin, skip_download=skip_download)
    elif spec.setup_kind == "huggingface":
        ensure_huggingface_assets(spec, python_bin=python_bin, skip_download=skip_download)
    else:  # pragma: no cover - guard for future extensions
        raise RuntimeError(f"unsupported setup kind: {spec.setup_kind}")

    emit_spec(spec, python_bin=python_bin)
    return 0


def main() -> int:
    args = parse_args()
    try:
        if args.command == "list":
            return run_list(plain=args.plain)
        if args.command == "resolve":
            return run_resolve(model=args.model, root_dir=args.root_dir)
        if args.command == "ensure":
            return run_ensure(
                model=args.model,
                root_dir=args.root_dir,
                python_bin=args.python,
                skip_download=args.skip_download,
            )
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print("ERROR: unknown command", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
