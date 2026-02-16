# Current Architecture (ASCII)

This reflects implemented Phase 2 + Phase 3 slices.

```text
User shortcut
    |
    v
+---------------------+
|   HotkeyController  |  (stub)
+---------------------+
    | ShortcutPressed / ShortcutReleased
    v
+------------------------------------------------------+
|                 SessionOrchestrator                  |
|  owns workflow + state transitions across modules    |
+------------------------------------------------------+
    | permission check              | state updates
    v                               v
+---------------------+        +---------------------+
|  PermissionManager  |        |      StatusUI       |
|       (stub)        |        |       (stub)        |
+---------------------+        +---------------------+
    | granted
    v
+---------------------+        +---------------------+
|    AudioCapture     |------->|      ASREngine      |
|       (stub)        | frames |       (stub)        |
+---------------------+        +---------------------+
            ^                            |
            |                            | PartialTranscript
            +------ AudioFrame ----------+
                                         v
                                  +---------------------+
                                  |      StatusUI       |
                                  |  (partial updates)  |
                                  +---------------------+
                                     | FinalTranscript
                                     v
                              +----------------------+
                              |  TextPostProcessor   |
                              +----------------------+
                                     |
                                     v
                              +----------------------+
                              |  FocusedFieldWriter  |
                              | AX primary + clip fb |
                              +----------------------+
                                     |
                                     v
                                InsertResult

Cross-cutting: SettingsStore, Logger (infra stubs)
Fast loop: DictationPreviewCLI (simulated transcript path)
Moonshine bridge:
  DictationPreviewCLI --moonshine-wav <file> -> MoonshineProcessASREngine
  -> python script (scripts/moonshine_transcribe.py) -> local Moonshine ONNX runtime
Live bridge:
  DictationPreviewCLI --moonshine-live -> AudioCapture (AVAudioEngine frames)
  -> SessionOrchestrator .audioFrame -> MoonshineProcessASREngine finalize
Insertion backends:
  AccessibilityDirectInserter -> kAXSelectedText / kAXValue
  ClipboardFallbackInserter -> pasteboard snapshot + Cmd+V + restore
Tests: StateMachineTests, SessionOrchestratorTests, TextPostProcessorTests
```
