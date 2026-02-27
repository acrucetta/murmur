import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from asr_model_catalog import ASRModelSpec
from asr_model_setup import (
    ensure_mlx_assets,
    ensure_moonshine_assets,
    is_apple_silicon,
    ensure_huggingface_assets,
    required_transformers_model_type,
)


class ASRModelSetupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.spec_qwen = ASRModelSpec(
            request="qwen3-asr-1.7b",
            provider="generic",
            runtime_model="Qwen/Qwen3-ASR-1.7B",
            runtime_script="/repo/scripts/hf_asr_transcribe.py",
            setup_kind="huggingface",
            setup_model_ref="Qwen/Qwen3-ASR-1.7B",
            trust_remote_code=True,
        )
        self.spec_whisper = ASRModelSpec(
            request="openai/whisper-small",
            provider="generic",
            runtime_model="openai/whisper-small",
            runtime_script="/repo/scripts/hf_asr_transcribe.py",
            setup_kind="huggingface",
            setup_model_ref="openai/whisper-small",
            trust_remote_code=False,
        )
        self.spec_qwen_mlx = ASRModelSpec(
            request="qwen3-asr-1.7b",
            provider="generic",
            runtime_model="mlx-community/Qwen3-ASR-1.7B-4bit",
            runtime_script="/repo/scripts/hf_asr_transcribe.py",
            setup_kind="mlx",
            setup_model_ref="mlx-community/Qwen3-ASR-1.7B-4bit",
            trust_remote_code=False,
        )
        self.spec_moonshine = ASRModelSpec(
            request="moonshine",
            provider="moonshine",
            runtime_model="medium-streaming-en",
            runtime_script="/repo/scripts/moonshine_transcribe.py",
            setup_kind="moonshine",
            setup_model_ref="medium-streaming-en",
            trust_remote_code=False,
        )

    def test_required_transformers_model_type_detects_qwen3_asr(self) -> None:
        self.assertEqual(
            required_transformers_model_type("Qwen/Qwen3-ASR-1.7B"),
            "qwen3_asr",
        )

    def test_required_transformers_model_type_is_none_for_other_models(self) -> None:
        self.assertIsNone(required_transformers_model_type("openai/whisper-small"))

    @patch("asr_model_setup.platform.system", return_value="Darwin")
    @patch("asr_model_setup.platform.machine", return_value="arm64")
    def test_is_apple_silicon_true_on_arm64_darwin(self, _machine_mock, _system_mock) -> None:
        self.assertTrue(is_apple_silicon())

    @patch("asr_model_setup.platform.system", return_value="Linux")
    @patch("asr_model_setup.platform.machine", return_value="x86_64")
    def test_is_apple_silicon_false_off_darwin_arm64(self, _machine_mock, _system_mock) -> None:
        self.assertFalse(is_apple_silicon())

    @patch("asr_model_setup._huggingface_snapshot_download", return_value=True)
    @patch("asr_model_setup.ensure_python_packages")
    @patch("asr_model_setup.modules_available", side_effect=[True, False])
    def test_ensure_huggingface_assets_installs_qwen_asr_runtime_when_missing(
        self,
        _modules_available_mock,
        ensure_python_packages_mock,
        _snapshot_download_mock,
    ) -> None:
        ensure_huggingface_assets(self.spec_qwen, python_bin="/venv/bin/python3", skip_download=False)

        ensure_python_packages_mock.assert_called_once_with(
            "/venv/bin/python3",
            ["qwen-asr"],
        )

    @patch("asr_model_setup._huggingface_snapshot_download", return_value=True)
    @patch("asr_model_setup.ensure_python_packages")
    @patch("asr_model_setup.modules_available", side_effect=[True, True])
    def test_ensure_huggingface_assets_skips_qwen_runtime_install_for_non_qwen(
        self,
        _modules_available_mock,
        ensure_python_packages_mock,
        _snapshot_download_mock,
    ) -> None:
        ensure_huggingface_assets(
            self.spec_whisper,
            python_bin="/venv/bin/python3",
            skip_download=False,
        )

        ensure_python_packages_mock.assert_not_called()

    @patch("asr_model_setup._huggingface_snapshot_download", return_value=True)
    @patch("asr_model_setup.ensure_python_packages")
    @patch("asr_model_setup.modules_available", side_effect=[False])
    def test_ensure_mlx_assets_installs_mlx_dependencies_when_missing(
        self,
        _modules_available_mock,
        ensure_python_packages_mock,
        _snapshot_download_mock,
    ) -> None:
        ensure_mlx_assets(self.spec_qwen_mlx, python_bin="/venv/bin/python3", skip_download=False)

        ensure_python_packages_mock.assert_called_once_with(
            "/venv/bin/python3",
            ["mlx>=0.23", "mlx-audio>=0.2", "huggingface_hub>=0.24"],
        )

    @patch("asr_model_setup.infer_moonshine_arch_and_language", return_value=("medium-streaming", "en"))
    @patch("asr_model_setup.ensure_python_packages")
    @patch("asr_model_setup.modules_available", return_value=True)
    @patch("asr_model_setup.run_command")
    def test_ensure_moonshine_assets_uses_module_api_download(
        self,
        run_command_mock,
        _modules_available_mock,
        ensure_python_packages_mock,
        _infer_mock,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            model_info = {
                "download_url": "https://models.example/moonshine/medium-streaming-en",
                "model_arch": "medium-streaming",
            }
            find_model_info_mock = unittest.mock.Mock(return_value=model_info)
            get_components_mock = unittest.mock.Mock(return_value=["encoder.onnx", "decoder.onnx"])
            download_model_mock = unittest.mock.Mock(return_value=("/tmp/model", "medium-streaming"))

            def import_module_side_effect(name: str):
                if name == "moonshine_voice":
                    return SimpleNamespace(string_to_model_arch=lambda arch: f"arch:{arch}")
                if name == "moonshine_voice.download":
                    return SimpleNamespace(
                        find_model_info=find_model_info_mock,
                        get_components_for_model_info=get_components_mock,
                        download_model_from_info=download_model_mock,
                    )
                if name == "moonshine_voice.download_file":
                    return SimpleNamespace(get_cache_dir=lambda: tmpdir)
                raise AssertionError(f"unexpected module import: {name}")

            with patch("asr_model_setup.importlib.import_module", side_effect=import_module_side_effect):
                ensure_moonshine_assets(
                    self.spec_moonshine,
                    python_bin="/venv/bin/python3",
                    skip_download=False,
                )

            ensure_python_packages_mock.assert_not_called()
            find_model_info_mock.assert_called_once_with(language="en", model_arch="arch:medium-streaming")
            download_model_mock.assert_called_once_with(model_info)
            run_command_mock.assert_not_called()


if __name__ == "__main__":
    unittest.main()
