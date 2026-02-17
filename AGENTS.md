# AGENTS.md

Repository operating guide for future agents. Keep this file short and map-like.

## 1) Quick Start
1. Read `docs/index.md`.
2. Read `docs/agents/README.md`.
3. Open the relevant spec in `docs/product-specs/`.
4. Open the current plan in `docs/exec-plans/active/`.
5. Run minimum failing test first (`red`), then implement (`green`).
6. Run verification commands and record outcomes in the plan.

## 2) Mandatory Defaults
- TDD is required for all non-trivial changes: `red -> green -> refactor`.
- Spec-first for non-trivial tasks: create/update a task spec before coding.
- Plans are first-class artifacts for non-trivial work.
- Keep module boundaries strict: orchestrate through `SessionOrchestrator`.
- No cloud dependency in runtime path.
- Report exactly what was verified and what was not run.

## 3) Source of Truth Map
- Docs map (start here): `docs/index.md`
- Agent workflow + constraints: `docs/agents/README.md`
- Architecture snapshot: `docs/agents/ARCHITECTURE_ASCII.md`
- Task spec template: `docs/agents/TASK_SPEC_TEMPLATE.md`
- Verification checklist: `docs/agents/VERIFICATION_CHECKLIST.md`
- Active and completed plans: `docs/exec-plans/`
- Product specs: `docs/product-specs/`
- Tech debt tracker: `docs/exec-plans/tech-debt-tracker.md`
- External pattern notes: `docs/agents/REFERENCE_NOTES.md`

## 4) Current Phase
- Core runtime is shipped: global hotkey flow, Moonshine local ASR bridge, insertion fallback, menu bar app, transcript history, shortcut CLI, one-command install, and recording feedback cues.
- Next phase focus: dictation quality/parity work (disfluency robustness, dictionary/context features) per `docs/product-specs/wisprflow-feature-gap-roadmap.md`.
