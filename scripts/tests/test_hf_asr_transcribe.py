import io
import json
import pathlib
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import hf_asr_transcribe


class HFASRTranscribeTests(unittest.TestCase):
    def test_requires_qwen_asr_runtime(self) -> None:
        self.assertTrue(hf_asr_transcribe.requires_qwen_asr_runtime("Qwen/Qwen3-ASR-1.7B"))
        self.assertFalse(hf_asr_transcribe.requires_qwen_asr_runtime("openai/whisper-small"))

    @patch("hf_asr_transcribe.load_transformers_transcriber")
    @patch("hf_asr_transcribe.load_qwen_asr_transcriber")
    @patch("hf_asr_transcribe.load_mlx_transcriber", return_value=lambda _: "hello from mlx")
    @patch("hf_asr_transcribe.is_apple_silicon", return_value=True)
    def test_load_transcriber_routes_qwen_models_to_mlx_on_apple_silicon(
        self,
        _apple_silicon_mock,
        mlx_mock,
        qwen_loader_mock,
        transformers_loader_mock,
    ) -> None:
        transcriber = hf_asr_transcribe.load_transcriber(
            model_id="mlx-community/Qwen3-ASR-0.6B-4bit",
            trust_remote_code=False,
        )

        self.assertEqual(transcriber(pathlib.Path("/tmp/x.wav")), "hello from mlx")
        mlx_mock.assert_called_once()
        qwen_loader_mock.assert_not_called()
        transformers_loader_mock.assert_not_called()

    @patch("hf_asr_transcribe.load_transformers_transcriber")
    @patch("hf_asr_transcribe.load_qwen_asr_transcriber", return_value=lambda _: "hello from qwen")
    @patch("hf_asr_transcribe.load_mlx_transcriber")
    @patch("hf_asr_transcribe.is_apple_silicon", return_value=False)
    def test_load_transcriber_routes_qwen_models_to_qwen_runtime_off_apple_silicon(
        self,
        _apple_silicon_mock,
        mlx_loader_mock,
        qwen_loader_mock,
        transformers_loader_mock,
    ) -> None:
        transcriber = hf_asr_transcribe.load_transcriber(
            model_id="Qwen/Qwen3-ASR-1.7B",
            trust_remote_code=False,
        )

        self.assertEqual(transcriber(pathlib.Path("/tmp/x.wav")), "hello from qwen")
        qwen_loader_mock.assert_called_once()
        mlx_loader_mock.assert_not_called()
        transformers_loader_mock.assert_not_called()

    @patch("hf_asr_transcribe.load_transcriber", return_value=lambda _: "hello from mlx")
    def test_main_routes_qwen_models_to_loaded_transcriber(
        self,
        load_transcriber_mock,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            wav_path = pathlib.Path(tmp_dir) / "sample.wav"
            wav_path.write_bytes(b"RIFF")
            args = SimpleNamespace(
                wav_path=str(wav_path),
                model="mlx-community/Qwen3-ASR-0.6B-4bit",
                trust_remote_code=False,
                server=False,
            )
            with patch("hf_asr_transcribe.parse_args", return_value=args):
                with patch("builtins.print") as print_mock:
                    exit_code = hf_asr_transcribe.main()

        self.assertEqual(exit_code, 0)
        load_transcriber_mock.assert_called_once()
        print_mock.assert_called_with("hello from mlx")

    @patch("hf_asr_transcribe.load_transcriber", return_value=lambda _: "hello from hf")
    def test_main_routes_non_qwen_models_to_transformers(
        self,
        load_transcriber_mock,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            wav_path = pathlib.Path(tmp_dir) / "sample.wav"
            wav_path.write_bytes(b"RIFF")
            args = SimpleNamespace(
                wav_path=str(wav_path),
                model="openai/whisper-small",
                trust_remote_code=False,
                server=False,
            )
            with patch("hf_asr_transcribe.parse_args", return_value=args):
                with patch("builtins.print") as print_mock:
                    exit_code = hf_asr_transcribe.main()

        self.assertEqual(exit_code, 0)
        load_transcriber_mock.assert_called_once()
        print_mock.assert_called_with("hello from hf")

    def test_run_server_emits_ready_and_result(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            wav_path = pathlib.Path(tmp_dir) / "sample.wav"
            wav_path.write_bytes(b"RIFF")
            requests = io.StringIO(
                f'{{"type":"transcribe","id":"abc","wav_path":"{wav_path}"}}\n'
                '{"type":"shutdown"}\n'
            )
            response_stream = io.StringIO()

            with patch("hf_asr_transcribe.load_transcriber", return_value=lambda _: "hello server"):
                exit_code = hf_asr_transcribe.run_server(
                    model_id="mlx-community/Qwen3-ASR-0.6B-4bit",
                    trust_remote_code=False,
                    input_stream=requests,
                    output_stream=response_stream,
                )

        self.assertEqual(exit_code, 0)
        lines = [json.loads(line) for line in response_stream.getvalue().splitlines() if line.strip()]
        self.assertEqual(lines[0]["type"], "ready")
        self.assertEqual(lines[1]["type"], "result")
        self.assertTrue(lines[1]["ok"])
        self.assertEqual(lines[1]["id"], "abc")
        self.assertEqual(lines[1]["text"], "hello server")

    def test_main_returns_error_for_missing_wav_file(self) -> None:
        args = SimpleNamespace(
            wav_path="/tmp/does-not-exist.wav",
            model="openai/whisper-small",
            trust_remote_code=False,
            server=False,
        )
        with patch("hf_asr_transcribe.parse_args", return_value=args):
            with patch("builtins.print") as print_mock:
                exit_code = hf_asr_transcribe.main()

        self.assertEqual(exit_code, 2)
        print_mock.assert_called()

    def test_extract_text_prefers_text_attribute(self) -> None:
        class ResultObject:
            text = "hello world"

        self.assertEqual(hf_asr_transcribe.extract_text(ResultObject()), "hello world")

    def test_extract_text_ignores_non_text_repr_when_text_attribute_empty(self) -> None:
        class ResultObject:
            text = ""

            def __str__(self) -> str:
                return "ASRTranscription(language='en', text='')"

        self.assertEqual(hf_asr_transcribe.extract_text(ResultObject()), "")


if __name__ == "__main__":
    unittest.main()
