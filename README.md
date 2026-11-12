# ServiceMate

A Flutter application for reading PDF manuals and asking questions
using an on-device language model.

## Current capabilities

- Import and view PDF manuals.
- Extract existing PDF text and create searchable passages.
- Search passages using BM25 keyword ranking.
- Generate answers using a local Qwen3 model.
- Display retrieved passages and open their PDF pages.
- Save, search, and delete question-and-answer history.
- Track manual preparation outcomes.
- Download a model with size and SHA-256 verification.
- Import a model from a local file.
- Show model registration and storage information.

## Requirements

Development currently uses Flutter 3.47.8.

AI answers require a compatible Qwen3 1.7B `.litertlm` model.
The configured download is approximately 977 MB. Installation
temporarily requires space for both the download and its installed copy.

Device performance and memory requirements need further testing.

## Run locally

```bash
git clone https://github.com/Sirish-konda/Servicemate.git
cd Servicemate
flutter pub get
flutter run
```

Native platform tooling is required for the selected target.
The project uses Flutter Edge AI with the LiteRT-LM engine.

## First use

Open model setup and download the configured model, or import
a compatible local file. Run the model test.

Import a text-based PDF and allow preparation to finish.
Open the manual and select Ask. Inspect the retrieved sources
and original PDF when checking an answer.

Model setup can be skipped. Reading PDFs and searching prepared
text do not require the language model.

After installation and preparation, the question-answering flow
is designed to work offline.

## How answering works

PDF text is extracted by page and split into overlapping passages.
BM25 ranks passages against the question. The answer service sends
the top passages and question to the local model.

Source references link the answer to retrieved passages.
Reference validation checks numbered citation ranges; it does not
verify factual accuracy.

## Code organisation

```text
lib/
  app/                         App startup UI and navigation
  core/
    llm/                       Model download, verification and inference
    services/                  First-use persistence
    theme/                     App theme
    widgets/                   Shared widgets
  features/
    home/
    manuals/
    chat/
    model_setup/
    settings/
```

The prototype uses StatefulWidget, setState, FutureBuilder, and
service classes. BLoC and Cubit are not currently used.

## Local storage

Manual folders contain the PDF, metadata, extracted text,
search passages, preparation status, and saved answer history.

Deleting a manual removes its app-managed folder and history.
It does not delete the original PDF selected outside the app.

Replacement model imports retain earlier model files.
Automatic cleanup and registration rollback are not implemented.

Do not commit downloaded model weights or personal manuals.

## Checks

```bash
flutter analyze
flutter test
```

GitHub Actions is configured to run analysis and tests on pushes
and pull requests. These checks do not exercise real model inference
or native PDF rendering.

## Known limitations

- Scanned PDFs need OCR, which is not implemented.
- Retrieval uses keyword ranking, not semantic embeddings.
- Extracted text may lose table structure and page layout.
- AI answers may be incorrect even when citations are valid.
- Questions are independent; saved history is not conversational memory.
- Downloads require the app to remain open and restart after interruption.

