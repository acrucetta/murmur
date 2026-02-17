# Wispr Flow Feature Gap Roadmap (Murmur)

Last updated: 2026-02-17  
Purpose: define the highest-impact Wispr Flow capabilities we should add next, with emphasis on transcription correctness for disfluencies (pauses, repeated words, false starts).

## 1) Current Murmur Baseline

Already working:
- Global push-to-talk hotkeys.
- Local Moonshine transcription bridge.
- Cross-app insertion (AX primary + clipboard fallback).
- Deterministic cleanup (basic spacing/capitalization/punctuation).
- Menu bar app + status.

Known gap: our cleanup is still basic and does not robustly handle natural disfluencies (filler-heavy speech, stutters, repair phrases).

## 2) Wispr Flow Capabilities To Target

Public Wispr material indicates these capabilities are key to perceived quality:
- Smart formatting + backtrack/self-correction phrases.
- Automatic filler cleanup.
- Pause/tone-aware punctuation behavior.
- Personal dictionary + misspelling correction map + auto-learn from edits.
- Context-aware spelling/style adaptation.
- Non-live insertion of polished final output (accuracy over streaming draft).

Reference links:
- https://wisprflow.ai/features
- https://docs.wisprflow.ai/articles/4297638257-smart-formatting-and-backtrack-in-wispr-flow
- https://docs.wisprflow.ai/articles/4052411709-teach-flow-your-words-with-the-dictionary
- https://docs.wisprflow.ai/articles/4678293671-feature-context-awareness
- https://docs.wisprflow.ai/articles/7419492456-why-flow-doesn-t-show-words-while-you-re-speaking

## 3) Priority Roadmap

### Now (build next)
- `P0` Disfluency-aware post-processing (`TextPostProcessorV2`).
- `P0` Repair/backtrack handling (`actually`, `scratch that`, `I mean`, `no wait` patterns).
- `P0` Repetition/stutter collapse (safe de-dup for accidental repeats).
- `P0` Smart formatting toggle (`smart` vs `literal` output mode).
- `P1` Local dictionary + misspelling correction map (manual first, auto-learn second).
- `P1` Metrics for cleanup quality (`dedupe_edits`, `filler_removed`, `repair_applied`).

### Next
- `P1` Local context hints from focused field (preceding text window, app bundle id).
- `P1` Snippets/voice shortcuts for common phrases.
- `P2` App-specific style profiles (docs/email/chat/code).

### Later
- `P2` Shared dictionaries/snippets for teams.
- `P2` Advanced code dictation transforms (identifier casing policies, shell-command strict mode).

### Out of scope for local-only runtime
- Cloud command mode / remote rewriting.
- Server-side personalization/training loops.

## 4) Disfluency Robustness Design (Core)

### 4.1 Processing pipeline order
1. Normalize transcript spacing.
2. Apply repair/backtrack rewrite rules.
3. Remove fillers (conservative lexical list).
4. Collapse accidental repetitions.
5. Apply pause-aware punctuation/sentence boundaries.
6. Final capitalization + terminal punctuation.

Ordering matters: repairs must run before de-duplication to avoid corrupting intended corrections.

### 4.2 Pauses and punctuation

Approach:
- Use pause duration signals from audio capture timeline (if available) and phrase boundaries.
- Default thresholds (tunable):
  - `>= 350ms`: phrase break candidate
  - `>= 700ms`: comma candidate
  - `>= 1200ms`: sentence boundary candidate
- Combine pause score with lexical cues (`and`, `but`, `so`, discourse markers) to reduce false periods.

Fallback when timing data is unavailable:
- Use text-only heuristics (length + conjunction + clause shape), lower confidence.

### 4.3 Repeated words and stutter collapse

Target failures:
- `I I I think we should go`
- `the the issue is`
- `we should should deploy`

Rules:
- Collapse immediate duplicate unigrams and bigrams when they are adjacent and not punctuation-separated.
- Aggressive mode for short function words (`i`, `the`, `a`, `to`, `and`) and repeated auxiliaries.
- Conservative mode for emphasis candidates (`very very`, `so so`) unless user enables strict dedupe.
- Keep a whitelist for intentional doubles (`had had`, product names with repeats, etc.) configurable over time.

### 4.4 Filler and hesitation handling

Target fillers:
- `um`, `uh`, `er`, `ah`, `you know`, `like` (context-sensitive).

Rules:
- Remove only when token appears as a standalone discourse filler.
- Do not remove semantic uses (example: `I like this`) by requiring surrounding pause/punctuation or filler-position patterns.
- Expose per-language filler lists via settings dictionary.

### 4.5 Repair/backtrack interpretation

Target phrases:
- `actually`, `scratch that`, `no wait`, `i mean`.

Rule model:
- Detect repair marker.
- Remove preceding short span (clause window) and keep replacement span.
- Window defaults:
  - remove up to previous punctuation or up to last 8-12 tokens.
- If confidence is low, keep original text and append replacement rather than destructive rewrite.

## 5) Data + Evaluation Plan

### 5.1 Test corpus (local)
- Build a small gold set (`~200` utterances) with labels:
  - pauses/punctuation
  - repeated words/stutters
  - fillers
  - repairs/false starts
- Include mixed scenarios and accented speech variants.

### 5.2 Metrics
- `WER_clean`: word error rate vs intended final text.
- `Punct_F1`: punctuation precision/recall.
- `Dedupe_precision`: accidental repeats removed / all removals.
- `Repair_success_rate`: repaired outputs matching intended revision.
- Latency impact:
  - `release_to_final_ms`
  - `release_to_insert_ms`
  - post-process budget target: `<= 30ms p95`.

### 5.3 Acceptance criteria for this phase
1. At least `30%` reduction in repeated-word artifacts on test corpus.
2. At least `25%` reduction in filler artifacts with `<3%` semantic false deletions.
3. Repair phrases correctly applied in `>=85%` labeled repair samples.
4. No regression to insertion reliability target (`>=95%` success on smoke apps).

## 6) TDD Execution Plan

Start with red tests in:
- `Tests/DictationAppCoreTests/TextPostProcessorTests.swift`
- `Tests/DictationAppCoreTests/SessionOrchestratorTests.swift` (for mode toggles/contract behavior)

Add test groups:
- `testRemovesStandaloneFillersNotSemanticLike`
- `testCollapsesImmediateRepeatedFunctionWords`
- `testPreservesIntentionalEmphasisWhenConfigured`
- `testAppliesBacktrackRewriteForActuallyPhrase`
- `testPauseAwareSentenceBoundaryFromTimingHints`
- `testLiteralModeDisablesSmartCleanup`

Implementation target files:
- `Sources/DictationAppCore/Modules/PostProcess/TextPostProcessor.swift`
- `Sources/DictationAppCore/Core/Events.swift` (if timing hints need explicit contract)
- `Sources/DictationAppCore/Infra/SettingsStore.swift` (smart/literal toggle + cleanup aggressiveness)

## 7) Suggested Incremental Delivery

Phase A (fast win):
- Repetition collapse + filler cleanup + toggle.

Phase B:
- Repair/backtrack rules + metrics.

Phase C:
- Dictionary misspelling map + auto-learn from user edits.

Phase D:
- Pause-aware punctuation using timing hints.

This keeps each merge small, reversible, and measurable.
