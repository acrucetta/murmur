# 2026-02-18 Log Formatting + Literal Default

## Problem Statement
Runtime logs were functional but inconsistent to scan quickly, and rewrite mode defaulted to `smart` even when users had not configured an LLM token.

## Scope
- Add a shared runtime log formatter with stable `ts` and `level` prefixes.
- Route CLI and menu bar metric output through the shared formatter.
- Change rewrite mode defaults from `smart` to `literal` across launcher/runtime entry points.
- Update docs and add formatter tests.

## Acceptance Criteria
1. Runtime log lines include consistent timestamp/level prefixes and keep existing event tokens for grep.
2. Default rewrite mode resolves to `literal` unless explicitly set otherwise.
3. Existing tests pass with the new logging utility and default behavior.

## Verification Commands
- `bash -n scripts/murmur`
- `swift test --filter RuntimeLogFormatterTests`
- `swift test --filter SessionOrchestratorTests --filter OpenRouterTranscriptRewriterTests`
- `swift build`
- `swift test`

## Result Summary
- Status: implemented and verified locally.
- Notes:
  - Added `RuntimeLogFormatter` and used it in CLI/menu bar logging sinks.
  - Preserved existing metric/event message content after the new `ts` and `level` prefix.
  - Switched defaults to `literal` in `scripts/murmur`, `MurmurMenuBarApp` argument resolution, `DictationPreviewCLI` config wizard default, and orchestrator fallback context.
