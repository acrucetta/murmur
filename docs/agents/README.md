# Agent Workflow

This repo uses a spec-driven harness workflow with strict TDD.

## Core Principles
- Keep `AGENTS.md` short and map-like.
- Keep durable detail in versioned docs, not chat memory.
- Use measurable acceptance criteria and explicit verification commands.
- Prefer narrow, reversible diffs with clear ownership boundaries.

## Standard Loop
1. Define/update task spec.
2. Define/update execution plan artifact.
3. Write failing tests first (`red`).
4. Implement minimal code to pass (`green`).
5. Refactor while preserving behavior.
6. Run full verification set and report outcomes.
7. Update docs/plans so future agents inherit context.

## Documentation Layout
- `docs/index.md`: entrypoint map for all repo knowledge.
- `docs/product-specs/`: stable product behavior and constraints.
- `docs/exec-plans/active/`: ongoing execution plans.
- `docs/exec-plans/completed/`: completed plan history.
- `docs/exec-plans/tech-debt-tracker.md`: recurring debt and cleanup queue.
- `docs/agents/`: agent-specific operational standards and templates.

## Required Spec Fields (non-trivial tasks)
- Problem statement.
- Scope and non-goals.
- Constraints (latency, reliability, privacy, compatibility).
- Interfaces/contracts affected.
- Acceptance criteria (observable).
- Verification commands.

Use `docs/agents/TASK_SPEC_TEMPLATE.md`.

## Required Plan Fields (non-trivial tasks)
- Objective and scope.
- Ordered implementation steps.
- Verification plan.
- Risks/blockers.
- Result summary with command outcomes.

## Verification Contract
- Always list commands actually run.
- Call out skipped checks and why.
- Record residual risks and assumptions.

Use `docs/agents/VERIFICATION_CHECKLIST.md`.

## Module Boundary Rule
- Modules do not directly coordinate each other.
- `SessionOrchestrator` owns cross-module workflow/state transitions.
- Shared behavior is exposed via typed events/contracts.

## Docs Hygiene
- Keep nearby docs updated when behavior or contracts change.
- Remove stale docs references during touched-file changes.
- Prefer small, frequent documentation maintenance over big rewrites.
