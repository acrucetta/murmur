# 2026-02-23 Completion History + Clipboard Retention

## Problem Statement
Users want Murmur to keep a durable system-file history of finalized inserted completions and keep pasted dictation text available in clipboard history after clipboard insertion.

## Scope
- In:
  - Persist each finalized completion to a stable append-only file under Murmur's Application Support directory.
  - Keep clipboard fallback pasted text on the clipboard (do not restore previous clipboard snapshot).
  - Add/adjust tests for both behaviors.
  - Update docs for history and clipboard behavior.
- Out:
  - Building a custom in-app clipboard manager.
  - Migrating or rewriting existing per-day transcript history format.

## Constraints
- Performance: No meaningful latency increase in insertion path.
- Reliability: Existing insertion success/failure semantics remain unchanged.
- Privacy/Security: Data remains local in user-owned `~/Library/Application Support/Murmur` files.
- Compatibility: macOS 13+ runtime; no cloud dependency added.

## Interfaces/Contracts Affected
- Files/modules:
  - `Sources/DictationAppCore/Infra/TranscriptHistoryStore.swift`
  - `Sources/DictationAppCore/Modules/Insertion/MacOSInserters.swift`
  - `Tests/DictationAppCoreTests/TranscriptHistoryStoreTests.swift`
  - `Tests/DictationAppCoreTests/...` clipboard insertion tests
  - `README.md`
- Event or API changes:
  - No public orchestrator contract changes.

## Acceptance Criteria
1. Finalized inserted text is persisted in system files under Murmur Application Support in a stable history log format.
2. Clipboard fallback insertion leaves dictated text on the clipboard after paste (previous clipboard is not auto-restored).
3. Existing insertion result reporting still works and targeted tests pass.

## Verification Commands
- `swift test --filter TranscriptHistoryStoreTests`
- `swift test --filter ClipboardFallbackInserterTests`
- `swift test --filter SessionOrchestratorTests`

## Risks/Blockers
- Changing clipboard restore behavior may surprise users who expected original clipboard restoration; document behavior clearly.

## Result Summary (to fill at completion)
- Implemented:
  - Added append-only completion history logging to `transcriptions/completions.log` in `FileTranscriptHistoryStore`.
  - Preserved existing daily transcript files and now write both daily + completion log per entry.
  - Updated clipboard fallback success behavior to keep dictated text on the clipboard (no restore on success).
  - Added red/green tests for completion log persistence and clipboard retention behavior.
  - Updated docs and `murmur doctor` output to surface completion-history file path and clipboard semantics.
- Verification run:
  - `swift test --filter TranscriptHistoryStoreTests --filter ClipboardFallbackInserterTests` (pass)
  - `swift test --filter SessionOrchestratorTests` (pass)
- Residual risks:
  - Users who expected pre-existing clipboard restoration will now see dictated text remain as latest clipboard value after successful clipboard insert.
