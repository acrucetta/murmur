# 2026-02-25 MLX Persistent ASR Worker

## Problem Statement
The generic HuggingFace/Qwen ASR path spawns a fresh Python subprocess per dictation. Each invocation loads PyTorch + model weights from scratch, consuming ~8GB RAM (Qwen 1.7B float32 on CPU) and taking 5-15 seconds before transcription begins. This makes the Qwen path unusable for interactive dictation. Additionally, if the Swift app crashes or is force-quit, orphaned Python processes keep that memory allocated indefinitely.

## Scope

### Part 1: MLX backend for Qwen ASR
- Replace the PyTorch/transformers Qwen codepath with an MLX-based backend using `mlx-audio`.
- Default to `mlx-community/Qwen3-ASR-0.6B-4bit` (708 MB) instead of `Qwen/Qwen3-ASR-1.7B` (8 GB).
- Keep `mlx-community/Qwen3-ASR-1.7B-4bit` (1.6 GB) as an optional higher-accuracy model.
- Update `asr_model_catalog.py` aliases so `qwen3-asr-0.6b` and `qwen3-asr-1.7b` resolve to MLX 4-bit variants by default on Apple Silicon.
- Update `asr_model_setup.py` to install `mlx` and `mlx-audio` instead of `torch`, `transformers`, `accelerate` when on Apple Silicon.
- Retain the PyTorch/transformers path as a fallback for non-Apple-Silicon machines (guarded by runtime architecture check).

### Part 2: Persistent subprocess with NDJSON protocol
- Add a `--server` mode to the HuggingFace/MLX transcription script. In server mode the script loads the model once, emits a `ready` message, then loops reading NDJSON requests from stdin and writing NDJSON responses to stdout.
- Introduce a `PersistentASRWorker` Swift type that manages the long-lived Python process: spawns on first transcription request, sends/receives NDJSON, handles crash recovery, and cleans up on deinit/app termination.
- Modify `GenericProcessASREngine` to use `PersistentASRWorker` instead of spawning a new `Process` per dictation.
- MoonshineProcessASREngine remains unchanged (per-process is fine at ~289 MB with native ONNX).

### Part 3: Orphan process prevention
- Set `terminationHandler` on the worker `Process` to detect unexpected exits.
- On app termination (`applicationWillTerminate` / `deinit`), send a `shutdown` command, close stdin, wait briefly, then `terminate()` → `kill()` as fallback.
- On worker crash mid-transcription: restart the worker once and retry the in-flight request. If the second attempt fails, surface an engine error.

## Non-goals
- Streaming/partial transcription over the NDJSON protocol (future work).
- Replacing Moonshine with MLX or making Moonshine persistent.
- Supporting non-macOS platforms or non-Apple-Silicon Macs with MLX (fall back to PyTorch).
- Quantization-aware fine-tuning or custom MLX model conversion.
- HTTP server or socket-based IPC (stdin/stdout is sufficient).

## Constraints
- Assume macOS on Apple Silicon (M1+). The MLX path must detect architecture at runtime and fall back to PyTorch on Intel.
- `SessionOrchestrator` interface is unchanged — it calls `start()`, `consume()`, `stopAndFinalize()` as before.
- The NDJSON protocol must be line-oriented (one JSON object per `\n`) with newlines escaped inside text fields.
- Python process must be launched with unbuffered I/O (`python -u` or `PYTHONUNBUFFERED=1` env var).
- Model download/setup remains a separate `murmur asr use <model>` step; the worker assumes assets are already local.

## NDJSON Protocol Spec

### Requests (Swift → Python via stdin)
```json
{"type":"transcribe","id":"<uuid>","wav_path":"/tmp/audio.wav"}
{"type":"shutdown"}
```

### Responses (Python → Swift via stdout)
```json
{"type":"ready","model":"mlx-community/Qwen3-ASR-0.6B-4bit","pid":12345}
{"type":"result","id":"<uuid>","ok":true,"text":"transcribed text here"}
{"type":"result","id":"<uuid>","ok":false,"error":"description of failure"}
```

### Rules
- Every `transcribe` request gets exactly one `result` response with a matching `id`.
- The first message from the worker after startup is always `ready`. Swift should wait for this with a timeout (60s for cold model load).
- `shutdown` causes the worker to flush, clean up, and exit with code 0.
- If the worker encounters a fatal error it writes a result with `ok:false` and continues running. Only unrecoverable errors (segfault, OOM) cause process exit.
- Stderr is reserved for debug logging; Swift drains it continuously but does not parse it as protocol.

## Interfaces/Contracts Affected
- `scripts/hf_asr_transcribe.py` — add `--server` flag, MLX transcription path, NDJSON loop.
- `scripts/asr_model_catalog.py` — update Qwen aliases to MLX model ids, add `setup_kind: "mlx"` variant.
- `scripts/asr_model_setup.py` — add MLX dependency installation path (`mlx`, `mlx-audio`), architecture detection.
- `Sources/DictationAppCore/Modules/ASR/GenericProcessASREngine.swift` — delegate to `PersistentASRWorker`.
- New: `Sources/DictationAppCore/Modules/ASR/PersistentASRWorker.swift` — process lifecycle, NDJSON codec, crash recovery.
- `Sources/DictationAppCore/Modules/ASR/ASREngineFactory.swift` — pass server-mode flag for generic engines.

## File-by-File Changes

### `scripts/hf_asr_transcribe.py`
- Add `--server` argument to `parse_args()`.
- Add `transcribe_with_mlx_audio(wav_path, model_id) -> str` function using `mlx_audio.stt`.
- Add `is_apple_silicon() -> bool` helper.
- Update `main()`: if `--server`, call new `run_server(model_id)` loop instead of one-shot transcription.
- `run_server()`: load model once, print `ready` JSON, loop on `stdin` reading NDJSON, dispatch to transcribe function, print `result` JSON with `flush=True`.
- Route Qwen models to MLX on Apple Silicon, fall back to PyTorch otherwise.

### `scripts/asr_model_catalog.py`
- Add MLX model entries: `qwen3-asr-0.6b-mlx`, `qwen3-asr-1.7b-mlx` with model refs to `mlx-community/Qwen3-ASR-0.6B-4bit` and `mlx-community/Qwen3-ASR-1.7B-4bit`.
- Update default `qwen3-asr-0.6b` and `qwen3-asr-1.7b` aliases to resolve to MLX variants on Apple Silicon (runtime detection in resolver).
- Add `setup_kind: "mlx"` for MLX entries.

### `scripts/asr_model_setup.py`
- Add `ensure_mlx_assets(spec, python_bin, skip_download)` function.
- Install `mlx` and `mlx-audio` via pip for MLX setup kind.
- Download MLX model via `huggingface_hub.snapshot_download` (same pattern as existing HF path).
- Add architecture detection: `platform.machine() == "arm64"` for Apple Silicon.

### `Sources/DictationAppCore/Modules/ASR/PersistentASRWorker.swift` (new)
- `PersistentASRWorker` class managing a single `Process` instance.
- `ensureRunning()` — spawn process if not alive, wait for `ready` message with 60s timeout.
- `transcribe(wavPath: String) -> String` — send `transcribe` request, read matching `result`, return text or throw.
- `shutdown()` — send `shutdown`, close stdin, wait 5s, terminate, wait 2s, kill.
- `deinit` calls `shutdown()`.
- Crash recovery: if process exits unexpectedly during `transcribe`, restart once and retry. Second failure throws.
- Stderr drain: background read handler that forwards to logger.
- NDJSON codec: `Codable` structs for request/response types.

### `Sources/DictationAppCore/Modules/ASR/GenericProcessASREngine.swift`
- Add a `PersistentASRWorker?` property, lazily initialized on first `stopAndFinalize()`.
- In `stopAndFinalize()`: write WAV to temp file, call `worker.transcribe(wavPath:)` instead of `runCommand`.
- In `start()`: no change (still buffers audio).
- Add `shutdown()` method that tears down the worker. Called from app termination path.

### `Sources/DictationAppCore/Modules/ASR/ASREngineFactory.swift`
- Pass `--server` flag in command array for generic engines so `PersistentASRWorker` launches in server mode.

## Acceptance Criteria
1. `murmur asr use qwen3-asr-0.6b` installs `mlx` + `mlx-audio` (not torch/transformers) on Apple Silicon and downloads the 4-bit model (~708 MB).
2. First dictation with Qwen ASR starts a persistent Python worker, loads the MLX model, and transcribes. Subsequent dictations reuse the same worker with no model reload.
3. Worker process memory stays under 1.5 GB for 0.6B-4bit and under 3 GB for 1.7B-4bit.
4. When the app quits normally, the worker process is terminated cleanly (no orphans).
5. If the worker crashes, the next dictation automatically restarts it and retries once.
6. Moonshine path is completely unaffected — still per-process, still works offline.
7. On Intel Macs, `qwen3-asr-*` falls back to PyTorch/transformers (existing behavior, non-persistent).
8. All existing tests pass. New tests cover:
   - NDJSON protocol encode/decode
   - `PersistentASRWorker` ready handshake and timeout
   - Successful transcribe round-trip
   - Worker crash detection and one-time restart
   - Shutdown sequence
   - MLX vs PyTorch routing based on architecture

## Verification Commands
- `python3 -m pytest scripts/tests/ -v`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter GenericProcessASREngineTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter PersistentASRWorkerTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox --filter ASREngineFactoryTests`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift test --disable-sandbox`
- `env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache SWIFTPM_CACHE_PATH=/tmp/swiftpm-cache SWIFTPM_CONFIG_PATH=/tmp/swiftpm-config SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security swift build --product MurmurMenuBarApp --disable-sandbox`
- Manual smoke: `echo '{"type":"transcribe","id":"test-1","wav_path":"test.wav"}' | python3 -u scripts/hf_asr_transcribe.py --model mlx-community/Qwen3-ASR-0.6B-4bit --server`

## Risks/Notes
- `mlx-audio` is a relatively new library; API surface may change. Pin version in setup.
- 4-bit quantization trades some accuracy for memory. Users who need maximum accuracy can use `qwen3-asr-1.7b-mlx` (bf16, ~4 GB) or the PyTorch fallback.
- The persistent worker holds GPU memory for the lifetime of the app. This is intentional for a dictation app but users running other GPU-intensive apps may notice contention.
- `ffmpeg` is recommended by `mlx-audio` for audio format handling. The worker receives WAV files (already converted by Swift), so this dependency may not be strictly required but should be documented.
- If the user switches models mid-session, the worker must be restarted with the new model. This is handled by `shutdown()` + lazy re-init on next `transcribe()`.
