#!/usr/bin/env python3
"""ASR model catalog and resolver for Murmur."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

_KNOWN_MOONSHINE_ARCHES = {
    "tiny",
    "base",
    "tiny-streaming",
    "base-streaming",
    "small-streaming",
    "medium-streaming",
}


@dataclass(frozen=True)
class ASRModelSpec:
    request: str
    provider: str
    runtime_model: str
    runtime_script: str
    setup_kind: str
    setup_model_ref: str
    trust_remote_code: bool


@dataclass(frozen=True)
class ASRModelCatalogEntry:
    alias: str
    provider: str
    runtime_model: str
    note: str


_QWEN_17B = "Qwen/Qwen3-ASR-1.7B"
_QWEN_06B = "Qwen/Qwen3-ASR-0.6B"

_CATALOG_ALIASES: dict[str, tuple[str, str, str, bool]] = {
    "moonshine": ("moonshine", "medium-streaming-en", "moonshine", False),
    "moonshine-medium": ("moonshine", "medium-streaming-en", "moonshine", False),
    "moonshine-medium-streaming": ("moonshine", "medium-streaming-en", "moonshine", False),
    "medium-streaming": ("moonshine", "medium-streaming-en", "moonshine", False),
    "medium-streaming-en": ("moonshine", "medium-streaming-en", "moonshine", False),
    "moonshine-small": ("moonshine", "small-streaming-en", "moonshine", False),
    "moonshine-small-streaming": ("moonshine", "small-streaming-en", "moonshine", False),
    "small-streaming": ("moonshine", "small-streaming-en", "moonshine", False),
    "small-streaming-en": ("moonshine", "small-streaming-en", "moonshine", False),
    "moonshine-base": ("moonshine", "base-streaming-en", "moonshine", False),
    "moonshine-base-streaming": ("moonshine", "base-streaming-en", "moonshine", False),
    "base": ("moonshine", "base-streaming-en", "moonshine", False),
    "base-streaming": ("moonshine", "base-streaming-en", "moonshine", False),
    "base-streaming-en": ("moonshine", "base-streaming-en", "moonshine", False),
    "moonshine-tiny": ("moonshine", "tiny-streaming-en", "moonshine", False),
    "moonshine-tiny-streaming": ("moonshine", "tiny-streaming-en", "moonshine", False),
    "tiny": ("moonshine", "tiny-streaming-en", "moonshine", False),
    "tiny-streaming": ("moonshine", "tiny-streaming-en", "moonshine", False),
    "tiny-streaming-en": ("moonshine", "tiny-streaming-en", "moonshine", False),
    "qwen3-asr-1.7b": ("generic", _QWEN_17B, "huggingface", True),
    "qwen3-1.7b": ("generic", _QWEN_17B, "huggingface", True),
    "qwen-1.7b": ("generic", _QWEN_17B, "huggingface", True),
    "qwen3-asr-0.6b": ("generic", _QWEN_06B, "huggingface", True),
    "qwen3-0.6b": ("generic", _QWEN_06B, "huggingface", True),
    "qwen-0.6b": ("generic", _QWEN_06B, "huggingface", True),
}

_CATALOG_ENTRIES: list[ASRModelCatalogEntry] = [
    ASRModelCatalogEntry(
        alias="moonshine",
        provider="moonshine",
        runtime_model="medium-streaming-en",
        note="Default local moonshine voice model.",
    ),
    ASRModelCatalogEntry(
        alias="moonshine-medium",
        provider="moonshine",
        runtime_model="medium-streaming-en",
        note="Moonshine medium streaming model (English).",
    ),
    ASRModelCatalogEntry(
        alias="moonshine-small",
        provider="moonshine",
        runtime_model="small-streaming-en",
        note="Smaller moonshine streaming model.",
    ),
    ASRModelCatalogEntry(
        alias="moonshine-base",
        provider="moonshine",
        runtime_model="base-streaming-en",
        note="Moonshine base streaming model (English).",
    ),
    ASRModelCatalogEntry(
        alias="moonshine-tiny",
        provider="moonshine",
        runtime_model="tiny-streaming-en",
        note="Moonshine tiny streaming model (English).",
    ),
    ASRModelCatalogEntry(
        alias="qwen3-asr-0.6b",
        provider="generic",
        runtime_model=_QWEN_06B,
        note="Qwen ASR via Hugging Face transformers runtime.",
    ),
    ASRModelCatalogEntry(
        alias="qwen3-asr-1.7b",
        provider="generic",
        runtime_model=_QWEN_17B,
        note="Higher-accuracy Qwen ASR via transformers runtime.",
    ),
]


def infer_moonshine_arch_and_language(model_hint: str) -> tuple[str, str]:
    """Infer moonshine arch/language from model name."""
    model_key = model_hint.strip().lower().split("/")[-1]
    language = "en"

    if model_key in _KNOWN_MOONSHINE_ARCHES:
        return model_key, language

    if model_key.endswith("-en"):
        without_lang = model_key[: -len("-en")]
        if without_lang in _KNOWN_MOONSHINE_ARCHES:
            return without_lang, "en"

    return "medium-streaming", language


def list_catalog_entries() -> list[ASRModelCatalogEntry]:
    return list(_CATALOG_ENTRIES)


def resolve_model_spec(requested_model: str, root_dir: Path) -> ASRModelSpec:
    requested = requested_model.strip()
    if not requested:
        raise ValueError("model id cannot be empty")

    normalized = requested.lower()
    provider: str
    runtime_model: str
    setup_kind: str
    trust_remote_code: bool

    if normalized in _CATALOG_ALIASES:
        provider, runtime_model, setup_kind, trust_remote_code = _CATALOG_ALIASES[normalized]
    elif normalized.startswith("moonshine:"):
        provider = "moonshine"
        runtime_model = requested.split(":", 1)[1].strip() or "medium-streaming-en"
        setup_kind = "moonshine"
        trust_remote_code = False
    elif normalized.startswith("hf:"):
        provider = "generic"
        runtime_model = requested.split(":", 1)[1].strip()
        if not runtime_model:
            raise ValueError("hf: model id is missing repository path")
        setup_kind = "huggingface"
        trust_remote_code = "qwen" in runtime_model.lower()
    elif "/" in requested:
        provider = "generic"
        runtime_model = requested
        setup_kind = "huggingface"
        trust_remote_code = "qwen" in runtime_model.lower()
    else:
        raise ValueError(
            "unknown model id. Use a known alias (e.g. qwen3-asr-1.7b, moonshine) "
            "or an explicit Hugging Face repo id like hf:org/model"
        )

    if provider == "moonshine":
        runtime_script = str(root_dir / "scripts" / "moonshine_transcribe.py")
    else:
        runtime_script = str(root_dir / "scripts" / "hf_asr_transcribe.py")

    return ASRModelSpec(
        request=requested,
        provider=provider,
        runtime_model=runtime_model,
        runtime_script=runtime_script,
        setup_kind=setup_kind,
        setup_model_ref=runtime_model,
        trust_remote_code=trust_remote_code,
    )
