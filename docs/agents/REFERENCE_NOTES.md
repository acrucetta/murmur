# Reference Notes

This doc records external patterns adopted for this repo's agent workflow.

## Adopted Patterns

### 1) Harness-Style Development
Adopted:
- Treat plans and evaluations as first-class artifacts.
- Keep agent instructions concise and references structured for progressive disclosure.
- Drive work with measurable checks and fast iteration loops.
- Continuously clean entropy (docs/process drift) during normal task flow.

Applied in:
- `AGENTS.md` map-style structure.
- `docs/index.md` knowledge map.
- `docs/exec-plans/` separation (`active` vs `completed`) and debt tracker.
- `docs/agents/TASK_SPEC_TEMPLATE.md` and `docs/agents/VERIFICATION_CHECKLIST.md`.

### 2) Codex Repository Agent Conventions
Adopted:
- Keep `AGENTS.md` concise and map-like.
- Put durable details in versioned docs instead of chat context.
- Maintain explicit, executable checks and clear handoff expectations.

Applied in:
- `AGENTS.md` source-of-truth map.
- `docs/agents/README.md` execution loop and docs hygiene rules.
- `docs/agents/ARCHITECTURE_ASCII.md` quick orientation artifact.

## Source Links
- OpenAI harness engineering article: https://openai.com/index/harness-engineering/
- Codex repo AGENTS.md pattern reference: https://raw.githubusercontent.com/openai/codex/main/AGENTS.md
