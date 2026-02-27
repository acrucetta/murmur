# 2026-02-27 Moonshine ASR Setup Arch Fix

## Problem Statement
`murmur config` failed during ASR setup for the `moonshine` alias because setup invoked:
`python -m moonshine_voice.download --model-arch medium-streaming`.
The installed `moonshine_voice.download` CLI expects a numeric `--model-arch`, so string values like `medium-streaming` fail.

## Scope
- Fix Moonshine setup path so alias-based model setup succeeds.
- Fix shell normalization helpers so `smart`/`true` values parse correctly on macOS default Bash.
- Add regression tests for Moonshine setup behavior.
- Validate all curated ASR model choices used by config/menu flows.

## Non-goals
- Change runtime transcription behavior.
- Change curated model list values.
- Download full model assets during verification.

## Constraints
- Keep compatibility with current Moonshine package APIs.
- Keep ASR setup deterministic and local-cache aware.

## Interfaces/Contracts Affected
- `scripts/asr_model_setup.py` (`ensure_moonshine_assets`)
- `scripts/asr_model_catalog.py` (moonshine base alias mapping)
- `scripts/murmur` (portable lowercase normalization)
- `scripts/tests/test_asr_model_setup.py`
- `scripts/tests/test_asr_model_catalog.py`

## Acceptance Criteria
1. `murmur asr use moonshine --skip-download` succeeds (no `invalid int value` error).
2. Moonshine setup no longer relies on the brittle `moonshine_voice.download` CLI `--model-arch` format.
3. `MURMUR_ASR_SKIP_DOWNLOAD=true` is respected in config/start/run paths.
4. Curated ASR options all succeed in setup path with `--skip-download`.
5. Python unit tests pass.

## Verification Commands
- `python3 -m unittest scripts/tests/test_asr_model_setup.py`
- `python3 -m unittest scripts/tests/test_asr_model_catalog.py`
- `python3 -m unittest discover -s scripts/tests`
- Option sweep (temp config):
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use moonshine --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use moonshine-small --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use moonshine-base --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use moonshine-tiny --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use qwen3-asr-1.7b --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use qwen3-asr-0.6b --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use openai/whisper-small --skip-download`
  - `MURMUR_CONFIG_DIR=/tmp/murmur-asr-option-test ./murmur asr use openai/whisper-medium --skip-download`
- Option sweep (real config):
  - `MURMUR_ASR_SKIP_DOWNLOAD=true ./murmur config set --asr-model <each-curated-option>`

## Result Summary
- Replaced Moonshine setup download invocation with Moonshine Python API calls (`string_to_model_arch`, `find_model_info`, `get_components_for_model_info`, `download_model_from_info`) instead of CLI arg parsing.
- Replaced non-portable Bash lowercase expansion (`${var,,}`) with a `tr`-based helper for compatibility with macOS default Bash.
- Mapped `moonshine-base` family aliases to `base-en`, which exists in current Moonshine model catalogs.
- Added regression test covering Moonshine API-driven download path and guarding against old subprocess path.
- Added catalog test covering `moonshine-base` alias resolution to `base-en`.
- Verified all curated ASR options complete setup successfully with `--skip-download` in isolated config and real config (`murmur config set --asr-model ...`), then restored original model.
