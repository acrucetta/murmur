# 2026-02-21 Adaptive Smart Rewrite Gating

## Problem Statement
Smart rewrite currently blocks insertion for expensive turns, even when local cleanup is already close to final output. This adds avoidable latency to the dictation loop.

## Scope
- In:
  - Improve local text cleanup quality for long run-on turns.
  - Add adaptive smart rewrite gating based on transcript/capture heuristics.
  - Add a strict runtime timeout budget for OpenRouter smart rewrite requests.
- Out:
  - Changing LLM provider/model family.
  - Background post-insert rewrite replacement UX.

## Constraints
- Keep insertion reliability and deterministic fallback behavior intact.
- Keep rewrite decisions observable in runtime logs.
- Keep changes narrow to post-processing/orchestration/runtime wiring.

## Interfaces/Contracts Affected
- `Sources/DictationAppCore/Modules/PostProcess/TextPostProcessor.swift`
- `Sources/DictationAppCore/Core/SessionOrchestrator.swift`
- `Sources/MurmurMenuBarApp/main.swift`
- `Tests/DictationAppCoreTests/TextPostProcessorTests.swift`
- `Tests/DictationAppCoreTests/SessionOrchestratorTests.swift`

## Acceptance Criteria
1. Local cleanup better handles capitalization/acronyms/run-on boundaries for common dictation prose.
2. Smart rewrite can be skipped with explicit low-need logs for high-confidence turns.
3. Smart rewrite network timeout is bounded by a low-latency budget by default.

## Verification Commands
- `swift test --filter TextPostProcessorTests --filter SessionOrchestratorTests`
- `swift test --filter OpenRouterTranscriptRewriterTests`
- `swift build`

## Result Summary
- Added smart-mode casing normalization and discourse boundary splitting in `TextPostProcessorV2`.
- Added adaptive rewrite need scoring in `SessionOrchestrator`:
  - logs `smart_rewrite_need score=...`
  - skips with `smart_rewrite_skipped reason=low_need ...` when below threshold.
  - low capture quality now contributes enough score to keep rewrite enabled (avoid skipping on likely noisy input).
- Added realistic smart-routing example matrix test in `SessionOrchestratorTests` to validate:
  - clean short requests skip rewrite
  - long run-ons can invoke rewrite
  - low capture quality invokes rewrite
  - user-style long phrase can stay local after cleanup
- Added OpenRouter timeout budget argument resolution in menu runtime:
  - default `700ms`
  - override via `--openrouter-timeout-ms` or `MURMUR_OPENROUTER_TIMEOUT_MS`.

## Verification Outcomes
- `swift test --filter TextPostProcessorTests --filter SessionOrchestratorTests` (pass)
- `swift test --filter OpenRouterTranscriptRewriterTests` (pass)
- `swift build` (pass)

## Risk Notes
- Heuristic gating may skip rewrite on some turns where user would prefer rewrite polish.
- Timeout budget may increase fallback-to-local frequency on slow networks.
