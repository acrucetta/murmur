# Phase 1 Task Spec

This file is retained for compatibility. Canonical docs are now:
- Product spec: `docs/product-specs/macos-local-dictation-mvp.md`
- Completed execution plan: `docs/exec-plans/completed/2026-02-16-phase-1-foundation.md`

## Problem Statement
Bootstrap an offline-first macOS dictation MVP foundation in an empty repository so Phase 2 (audio + ASR) can build on stable contracts and tested orchestration.

## Scope
- Swift package structure matching the module map (`App`, `Core`, `Modules`, `Infra`).
- Typed events, failure codes, and insertion method contracts.
- Session state machine and orchestrator skeleton.
- Phase 1 stubs for permissions, hotkey, status UI, audio, ASR, insertion, and settings/logger infra.
- Unit tests for state transitions, orchestrator happy path, permission-denied path, and text cleanup rules.

## Non-Goals
- Real global hotkey hooks.
- Real macOS permission prompts.
- Real audio capture, Moonshine integration, and cross-app insertion.

## Constraints
- Keep runtime architecture local-only and event-contract driven.
- Enforce module communication through `SessionOrchestrator`.
- Keep implementation small and reversible.

## Acceptance Criteria (Phase 1)
- `swift test` passes locally.
- State transitions match MVP flow and error reset behavior.
- Permission-denied on shortcut press does not start audio/ASR and surfaces error state.
- Happy path cleans transcript and attempts insert once.

## Verification Commands
- `swift test`
