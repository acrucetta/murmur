import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from asr_model_catalog import (
    infer_moonshine_arch_and_language,
    list_catalog_entries,
    resolve_model_spec,
)


class ASRModelCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.root_dir = pathlib.Path("/repo")

    @patch("asr_model_catalog.is_apple_silicon", return_value=True)
    def test_resolves_qwen_alias_to_generic_mlx_on_apple_silicon(self, _is_apple_silicon) -> None:
        spec = resolve_model_spec("qwen3-asr-1.7b", root_dir=self.root_dir)

        self.assertEqual(spec.provider, "generic")
        self.assertEqual(spec.runtime_model, "mlx-community/Qwen3-ASR-1.7B-4bit")
        self.assertTrue(spec.runtime_script.endswith("scripts/hf_asr_transcribe.py"))
        self.assertFalse(spec.trust_remote_code)
        self.assertEqual(spec.setup_kind, "mlx")

    @patch("asr_model_catalog.is_apple_silicon", return_value=False)
    def test_resolves_qwen_alias_to_generic_huggingface_off_apple_silicon(self, _is_apple_silicon) -> None:
        spec = resolve_model_spec("qwen3-asr-1.7b", root_dir=self.root_dir)

        self.assertEqual(spec.provider, "generic")
        self.assertEqual(spec.runtime_model, "Qwen/Qwen3-ASR-1.7B")
        self.assertTrue(spec.runtime_script.endswith("scripts/hf_asr_transcribe.py"))
        self.assertTrue(spec.trust_remote_code)
        self.assertEqual(spec.setup_kind, "huggingface")

    @patch("asr_model_catalog.is_apple_silicon", return_value=True)
    def test_resolves_legacy_raw_qwen_repo_to_mlx_on_apple_silicon(self, _is_apple_silicon) -> None:
        spec = resolve_model_spec("Qwen/Qwen3-ASR-1.7B", root_dir=self.root_dir)

        self.assertEqual(spec.provider, "generic")
        self.assertEqual(spec.runtime_model, "mlx-community/Qwen3-ASR-1.7B-4bit")
        self.assertEqual(spec.setup_kind, "mlx")
        self.assertFalse(spec.trust_remote_code)

    def test_resolves_moonshine_prefixed_model(self) -> None:
        spec = resolve_model_spec("moonshine:small-streaming-en", root_dir=self.root_dir)

        self.assertEqual(spec.provider, "moonshine")
        self.assertEqual(spec.runtime_model, "small-streaming-en")
        self.assertTrue(spec.runtime_script.endswith("scripts/moonshine_transcribe.py"))
        self.assertFalse(spec.trust_remote_code)

    def test_resolves_huggingface_repo_id_directly(self) -> None:
        spec = resolve_model_spec("openai/whisper-small", root_dir=self.root_dir)

        self.assertEqual(spec.provider, "generic")
        self.assertEqual(spec.runtime_model, "openai/whisper-small")
        self.assertTrue(spec.runtime_script.endswith("scripts/hf_asr_transcribe.py"))

    def test_infers_moonshine_arch_and_language_from_en_suffix(self) -> None:
        self.assertEqual(
            infer_moonshine_arch_and_language("medium-streaming-en"),
            ("medium-streaming", "en"),
        )

    def test_unknown_moonshine_hint_falls_back_to_medium_streaming(self) -> None:
        self.assertEqual(
            infer_moonshine_arch_and_language("some-custom-moonshine-hint"),
            ("medium-streaming", "en"),
        )

    def test_catalog_lists_all_curated_moonshine_aliases(self) -> None:
        aliases = [entry.alias for entry in list_catalog_entries()]
        self.assertIn("moonshine", aliases)
        self.assertIn("moonshine-medium", aliases)
        self.assertIn("moonshine-small", aliases)
        self.assertIn("moonshine-base", aliases)
        self.assertIn("moonshine-tiny", aliases)
        self.assertIn("qwen3-asr-0.6b", aliases)
        self.assertIn("qwen3-asr-1.7b", aliases)


if __name__ == "__main__":
    unittest.main()
