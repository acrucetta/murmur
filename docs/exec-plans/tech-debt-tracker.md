# Tech Debt Tracker

## Open Items

1. Replace stubbed macOS integrations with real implementations.
- Areas: `Modules/Permissions`, `Modules/ASR`.
- Why: hotkey and insertion/live capture bridges now exist, but permission onboarding and ASR robustness are still incomplete.

2. Harden live microphone capture quality and permission UX.
- Areas: `Modules/Audio`, `DictationPreviewCLI`, `Modules/Permissions`.
- Why: live bridge exists, but quality/reliability and user prompts need production hardening.

3. Add latency measurement plumbing.
- Metrics: `release_to_final_ms`, `release_to_insert_ms` (p50/p95).
- Why: required by product acceptance criteria.

4. Expand app-level insertion smoke coverage across target editors.
- Focus: Notes, Slack, browser textarea, VS Code, and secure field behavior.
- Why: policy tests now exist, but cross-app runtime behavior still needs structured validation.
