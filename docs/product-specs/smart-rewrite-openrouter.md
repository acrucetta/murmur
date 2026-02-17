# Smart Rewrite Mode (OpenRouter)

Last updated: 2026-02-17

## Purpose

Add an optional context-aware rewrite path that improves dictation polish (accent/homophone corrections, phrasing, punctuation) while preserving Murmur's fast baseline and local-first defaults.

## Modes

- `smart` (default):
  - Always applies local deterministic cleanup (`TextPostProcessorV2(mode: .smart)`).
  - Optionally applies OpenRouter rewrite when API key is present.
- `literal`:
  - Applies local minimal cleanup (`TextPostProcessorV2(mode: .literal)`).
  - No LLM rewrite.

## Runtime configuration

Environment:

- `MURMUR_REWRITE_MODE=literal|smart`
- `MURMUR_OPENROUTER_MODEL=mistralai/mistral-small-3.1-24b-instruct` (default)
- `MURMUR_OPENROUTER_API_KEY=<token>` (preferred)
- `OPENROUTER_API_KEY=<token>` (fallback)

CLI flags:

- `--rewrite-mode literal|smart`
- `--openrouter-model <id>`
- `--openrouter-api-key <token>` (supported; env var preferred)

Interactive CLI setup:

- `murmur config`
  - configure primary shortcut (keep/capture/type/reset)
  - choose rewrite mode (`literal` / `smart`)
  - configure model id for smart mode
  - prompt for OpenRouter API key (set/replace/clear)
  - review and confirm all changes before persist

## Safety and fallback behavior

1. If smart rewrite is disabled/misconfigured, Murmur inserts local cleaned text.
2. If OpenRouter returns transport error/non-2xx/invalid payload, Murmur inserts local cleaned text.
3. API key values are never logged.

## Context hints sent to rewrite

Current lightweight hints:
- `frontmost_app_bundle_id`
- `frontmost_app_name`
- mode metadata (`smart`/`literal`)
- cleaned transcript text

This phase intentionally avoids deep context scraping to reduce risk and latency.
