# 2026-02-17 Transcript History and CLI UX

## Objective
Add user-visible local transcription history and keep CLI operation simple for foreground/background workflows.

## Scope
- Persist cleaned transcriptions locally with timestamp + insertion metadata.
- Wire history recording into real dictation runtimes.
- Add CLI commands to inspect local history.
- Document run/start behavior and history location.

## Non-Goals
- Cloud sync/export.
- History deletion/retention UI.
- Encryption at rest.

## Steps
1. Added failing tests for orchestrator history recording and file-backed history persistence.
2. Implemented `TranscriptHistoryWriting` contracts and `FileTranscriptHistoryStore`.
3. Wired `SessionOrchestrator` to record cleaned transcript + insert result.
4. Wired live CLI and menu bar app to use the file-backed store.
5. Added `murmur history` and `murmur history-path` commands.
6. Updated docs with run vs start behavior and history location.

## Verification Commands
- `swift test`
- `bash -n scripts/murmur`
- `murmur history-path`
- `murmur history 5`

## Verification Results
- `swift test` passed (`45` tests).
- `bash -n scripts/murmur` passed.
- `murmur history-path` prints `~/Library/Application Support/Murmur/transcriptions` resolved path.
- `murmur history 5` returns history lines or `no transcript history yet`.

## Outcome
- Every finalized cleaned transcript from real run modes is now persisted locally.
- Users can inspect history quickly from CLI without opening files manually.
- CLI semantics are explicit (`run` foreground, `start` background).

## Residual Risks
- History currently grows indefinitely (no rotation/retention policy yet).
- Entries are plaintext on disk.
