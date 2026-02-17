# Current Architecture (ASCII)

This reflects the current shipped runtime (hotkey + Moonshine + insertion fallback + menu bar feedback).

```text
User shortcut
    |
    v
+---------------------+
|   HotkeyController  |  (global Carbon listener)
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
| runtime checks flow |        | menu bar state text |
+---------------------+        +---------------------+
    | feedback events
    v
 +-----------------------+
 |   FeedbackPresenter   |
 | start/stop cues only  |
 +-----------------------+
    | concrete runtime
    v
 +-----------------------+
 | AppKit sound + haptic |
 +-----------------------+
    | granted
    v
+---------------------+        +------------------------------+
|    AudioCapture     |------->|      ASREngine               |
| AVAudioEngine frames| frames | MoonshineProcessASREngine    |
+---------------------+        +------------------------------+
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
                              | TextPostProcessorV2  |
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

Cross-cutting: SettingsStore, Logger
Feedback contract:
  SessionOrchestrator -> FeedbackPresenter (.recordingStarted/.recordingStopped)
  Menu bar app runtime plays bundled custom WAV cues + haptics
  Non-GUI runtime uses no-op presenter (no terminal bell)
Fast loop: DictationPreviewCLI (simulated transcript path)
Moonshine bridge:
  DictationPreviewCLI --moonshine-wav <file> -> MoonshineProcessASREngine
  -> python script (scripts/moonshine_transcribe.py)
  -> moonshine_voice (primary, medium-streaming-en default)
  -> moonshine_onnx (fallback)
Live bridge:
  DictationPreviewCLI --moonshine-live -> AudioCapture (AVAudioEngine frames)
  -> SessionOrchestrator .audioFrame -> MoonshineProcessASREngine finalize
  -> deferred insertion on key release (no live field insertion)
Hotkey daemon bridge:
  DictationPreviewCLI --hotkey-daemon -> HotkeySessionBridge
  -> SessionOrchestrator shortcut events
Insertion backends:
  AccessibilityDirectInserter -> kAXSelectedText / kAXValue
  ClipboardFallbackInserter -> pasteboard snapshot + Cmd+V + restore
Tests: StateMachineTests, SessionOrchestratorTests, TextPostProcessorTests
```
