# 2026-02-19 Menu Bar Settings Surface

## Objective
Expose the most-used Murmur runtime settings directly in the macOS menu bar menu, and keep the icon visually stable during recording.

## Scope
- Add menu controls for:
  - rewrite mode (`literal` / `smart`)
  - smart rewrite model selection
  - pause media while recording toggle
  - microphone selection (system default + discovered devices)
- Show quick settings context in menu (shortcut).
- Persist menu changes to the same config files used by `murmur config set`.
- Remove status icon tint changes while recording/error.
- Keep menu concise by removing debug/status rows and extra helper rows.

## Non-goals
- Full in-menu replacement of CLI wizard (`shortcut` capture and API key editing stay in CLI).
- Live hot-reload of all runtime components after menu changes.

## Constraints
- Keep changes narrow and local to menu bar wiring.
- Preserve existing runtime behavior unless user explicitly changes settings.
- Keep config file compatibility with existing launcher script.

## Verification
- `swift test --disable-sandbox`
- Manual smoke (menu opens, settings are selectable, icon remains same color across states)

## Result Summary
- Menu now includes a settings section with rewrite mode/model, pause-media toggle, and microphone picker.
- Settings writes go to existing Murmur config files under `~/Library/Application Support/Murmur`.
- Menu shows current shortcut for quick diagnostics.
- Icon no longer changes tint for listening/error states.
