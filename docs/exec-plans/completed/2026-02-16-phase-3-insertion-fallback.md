# 2026-02-16 Phase 3 Insertion Fallback

## Objective
Implement MVP text insertion strategy with accessibility-direct primary path and exactly one clipboard fallback path.

## Scope
- Replace insertion stub with policy-driven `FocusedFieldWriter`.
- Add deterministic tests for fallback behavior and failure mapping.
- Add macOS inserter backends:
  - AX direct insert
  - Clipboard paste fallback

## Non-Goals
- Full production-grade editor compatibility matrix.
- Rich cursor/selection manipulation for every app edge case.

## Steps
1. Added failing tests for insertion policy and fallback behavior.
2. Implemented `FocusedFieldWriter` with one fallback attempt.
3. Implemented macOS backend adapters for AX direct and clipboard fallback paths.
4. Ran `swift test`.

## Verification Commands
- `swift test`

## Verification Results
- `swift test` passed (20 tests).

## Outcome
- `FocusedFieldWriter` now executes AX primary insertion path and falls back exactly once to clipboard.
- Added deterministic tests for fallback policy:
  - primary success (no fallback)
  - primary failure with fallback success
  - both paths failure
  - no fallback for non-insertion engine error
- Added concrete macOS inserters:
  - `AccessibilityDirectInserter`
  - `ClipboardFallbackInserter`

## Residual Risks
- AX behavior differs across target apps and secure fields.
- Clipboard fallback uses synthetic Cmd+V and depends on accessibility/input-monitoring permissions.
