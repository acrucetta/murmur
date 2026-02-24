# Gemini Project Helper: Murmur

This document provides essential information for working on the Murmur project.

## Project Overview

Murmur is a macOS dictation application that runs in the menu bar. It provides features like global hotkeys for dictation, automatic text insertion, smart transcript rewriting, and audio feedback. It appears to have a modular architecture, allowing for different components like ASR (Automatic Speech Recognition) engines to be swapped out.

## Tech Stack

- **Primary Language:** Swift
- **Package Manager:** Swift Package Manager (SPM)
- **UI:** A combination of a native macOS menu bar application and a terminal-based configuration wizard (using TermKit).
- **Backend/ASR:** It seems to use an external process for speech recognition, potentially a Python script (`moonshine_transcribe.py`).

## Key Commands

### Build the project
```bash
swift build
```

### Run the main application (Menu Bar App)
```bash
swift run MurmurMenuBarApp
```

### Run the command-line configuration wizard
```bash
swift run DictationPreviewCLI
```

### Run tests
```bash
swift test
```

## Project Structure

- `Sources/`: Contains all the source code.
    - `MurmurMenuBarApp/`: The entry point for the main macOS menu bar application.
    - `DictationAppCore/`: The core logic of the dictation app, including state management, audio handling, and various modules for different functionalities.
    - `DictationPreviewCLI/`: Source for the command-line interface, likely for configuration and testing.
- `Tests/`: Unit and integration tests for the `DictationAppCore`.
- `scripts/`: Contains helper scripts, including what appears to be a Python-based transcription service.
- `docs/`: Contains product specifications, architecture notes, and execution plans.

## Development Notes

- The application is architected around a central `SessionOrchestrator` which manages the dictation session lifecycle.
- State is managed using a `StateMachine`.
- Configuration appears to be handled via a CLI and stored locally.
- Pay attention to the existing conventions and coding style in the Swift files.
- When adding new features, also add corresponding tests in the `Tests/` directory.
