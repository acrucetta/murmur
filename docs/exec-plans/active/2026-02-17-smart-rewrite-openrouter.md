# 2026-02-17 Smart Rewrite (Literal vs Smart + OpenRouter)

## Problem Statement
Murmur is fast but still misses Wispr-like polish for accented/mispronounced words and context-sensitive phrasing. We need optional context-aware rewrite while keeping low latency and preserving safe literal behavior.

## Scope
- In:
  - Add rewrite mode selection: `literal` and `smart`.
  - Add optional OpenRouter-backed rewrite path used only in `smart` mode.
  - Enforce hard smart rewrite budget of `150ms` max.
  - Add graceful fallback to deterministic local cleanup when rewrite is unavailable, times out, or fails.
  - Include lightweight context hints in smart rewrite requests.
- Out:
  - Streaming partial rewrite.
  - Heavy app-specific style engines.
  - Replace-after-insert cross-app mutation path.

## Constraints
- Performance:
  - Smart rewrite budget <= `150ms` end-to-end from rewrite invocation to result selection.
  - No additional delay in `literal` mode.
- Reliability:
  - If smart rewrite fails or times out, insertion still succeeds using existing cleaned text.
  - No regression to current insertion pipeline and fallback behavior.
- Privacy/Security:
  - Default path remains local only.
  - OpenRouter usage is opt-in only.
  - API key must be provided via environment and never logged.
- Compatibility:
  - Existing commands (`murmur run/start/restart`) continue working without extra flags.

## Interfaces/Contracts Affected
- `Sources/DictationAppCore/Core/SessionOrchestrator.swift`
- `Sources/DictationAppCore/Modules/PostProcess/TextPostProcessor.swift`
- `Sources/DictationAppCore/Infra/SettingsStore.swift`
- `Sources/MurmurMenuBarApp/main.swift`
- `scripts/murmur`
- New rewrite module files under `Sources/DictationAppCore/Modules/Rewrite/`

## Acceptance Criteria
1. `literal` mode inserts deterministic cleaned text exactly as current behavior.
2. `smart` mode attempts rewrite only when OpenRouter config/token are provided.
3. Smart rewrite times out at `150ms` and falls back cleanly with no error state transition.
4. Smart rewrite request includes context hints (at least front app identifier + mode metadata).
5. Logs remain actionable and redact token values.

## Verification Commands
- `swift test --filter SessionOrchestratorTests`
- `swift test --filter TextPostProcessorTests`
- `swift test --filter OpenRouterTranscriptRewriterTests`
- `swift test`
- `swift build`

## Ordered Implementation Steps
1. Add failing tests for rewrite mode behavior and timeout fallback in orchestrator.
2. Add failing tests for OpenRouter request construction and timeout handling.
3. Implement rewrite protocols and OpenRouter rewriter with hard timeout.
4. Wire runtime argument/env parsing for rewrite mode/model/token.
5. Update launcher script + README docs for smart mode usage.
6. Run verification commands and record outcomes.

## Risks/Blockers
- Network latency may exceed budget frequently; fallback behavior must be robust.
- Aggressive rewriting can alter meaning; guardrails may need tuning in follow-up.
- App context extraction is intentionally lightweight in this phase to keep risk low.

## Result Summary (to fill at completion)
- Status: implemented and verified locally (awaiting user runtime validation)
- Commands run:
  - `swift test --filter SessionOrchestratorTests --filter OpenRouterTranscriptRewriterTests` (pass)
  - `swift test --filter OpenRouterTranscriptRewriterTests` (pass)
  - `swift build` (pass)
  - `swift test` (pass)
- Residual risks:
  - Smart rewrite quality is model/provider dependent and may vary by prompt/latency conditions.
  - This phase uses lightweight context hints (frontmost app metadata), not deep field context windows.
