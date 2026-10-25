<div align="center">

# 🧠 Linkless AI

**A fully offline AI & Vision assistant for Windows — no API keys, no cloud, no internet required.**  
Built with Flutter + custom fine-tuned GGUF models running on llama.cpp, with multimodal vision, multi-document RAG, and voice input — all on-device.

<br/>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![llama.cpp](https://img.shields.io/badge/llama.cpp-GGUF-8B5CF6?style=for-the-badge)
![Riverpod](https://img.shields.io/badge/Riverpod-State_Mgmt-00BCD4?style=for-the-badge)
![CUDA](https://img.shields.io/badge/CUDA-GPU_Accelerated-76B900?style=for-the-badge&logo=nvidia&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

</div>

---

## 📽️ Section 1 — 30-Second Live Demo

> **Coming soon** — screen recording in progress.  
> The demo will show: chat with streaming Markdown, image Q&A via the vision model, multi-document RAG over a PDF, and real-time model switching.

<!--
Once you have the recording, replace this block with:

[![Demo Video](https://img.youtube.com/vi/YOUR_VIDEO_ID/maxresdefault.jpg)](https://youtu.be/YOUR_VIDEO_ID)

Or embed a GIF:
![Demo GIF](docs/demo.gif)
-->

---

## 🖼️ Section 2 — Screenshots Gallery

> **Note:** Drop screenshots into `docs/screenshots/` and they will render here automatically.

| Chat — Markdown + Streaming | Vision — Image Q&A |
|:---:|:---:|
| ![Chat UI](docs/screenshots/chat_markdown.png) | ![Vision Mode](docs/screenshots/vision_mode.png) |

| Document RAG — PDF / DOCX | Settings & Model Switcher |
|:---:|:---:|
| ![Document RAG](docs/screenshots/doc_rag.png) | ![Settings](docs/screenshots/settings.png) |

---

## ⚡ Section 3 — Try It Yourself (Release v0.1.0)

### Requirements
- Windows 10 / 11 (x64)
- ~4 GB RAM minimum (8 GB recommended for vision model)
- NVIDIA GPU optional — CPU fallback is automatic

### Step 1 — Download the app

👉 **[Download `linkless_ai.exe` from Releases →](https://github.com/viraj/linkless_ai/releases/tag/v0.1.0)**

> The release is a standalone `.exe`. No Flutter or Dart installation needed.

### Step 2 — Download models & llama.cpp binaries

Clone or download this repo, then run the bootstrap script from the project root:

```bat
download_models.bat
```

This script automatically downloads:

| File | Size | Source |
|---|---|---|
| `Linkless-AI-Pro-Q4_K_M.gguf` | ~1 GB | Hugging Face Hub |
| `Linkless-AI-VL-Q4_K_M.gguf` | ~940 MB | Hugging Face Hub |
| `mmproj-Linkless-AI-VL-f16.gguf` | ~1.27 GB | Hugging Face Hub |
| `llama-server.exe` + DLLs | ~180 MB | llama.cpp GitHub Releases |

### Step 3 — Launch & configure

1. Run `linkless_ai.exe`
2. Open **Settings → Server** and set the llama-server path to `llama-cpp\llama-server.exe`
3. The app auto-detects all `.gguf` files in the `models\` folder
4. Press **Start Server** — you're ready to chat 🚀

---

## 🏗️ Section 4 — About the Project & Architecture

### What is Linkless AI?

Linkless AI is a Windows desktop application that runs **locally fine-tuned large language models** on-device — with zero cloud dependency, zero subscriptions, and zero data leaving your machine. It was built to demonstrate that powerful AI assistants can run entirely offline on consumer hardware.

### Key Features

| Feature | Details |
|---|---|
| 🧠 **Offline AI Chat** | Streaming token-by-token responses with full Markdown rendering |
| 👁️ **Multimodal Vision** | Attach images and ask questions; powered by a fine-tuned VL model |
| 📄 **Multi-Document RAG** | Attach PDFs, DOCX, EPUB, Excel, CSV — text extracted and injected into context |
| 🎙️ **Voice Input** | Speech-to-text via Windows SAPI (no external API) |
| 💾 **Persistent History** | Conversations stored locally in SQLite |
| 🎨 **Custom Fine-tuned Models** | Both text and vision models are fine-tuned from Qwen2.5-3B base |

### Architecture

```
┌─────────────────────────────────────────────────┐
│               Flutter Desktop UI                 │
│  (Riverpod state • Screens • Widgets • Themes)  │
└─────────────────┬───────────────────────────────┘
                  │  HTTP (localhost:8080)
                  │  OpenAI-compatible /v1/chat/completions
                  │  SSE streaming
                  ▼
┌─────────────────────────────────────────────────┐
│              llama-server.exe                    │
│         (llama.cpp, CUDA or CPU backend)         │
└─────────────────┬───────────────────────────────┘
                  │  loads
        ┌─────────┴──────────┐
        ▼                    ▼
┌───────────────┐   ┌────────────────────────────┐
│  Text Model   │   │  Vision Model + mmproj     │
│  Pro Q4_K_M   │   │  VL Q4_K_M + f16 projector │
│  (~1 GB GGUF) │   │  (~2.2 GB total GGUF)      │
└───────────────┘   └────────────────────────────┘
```

#### Layer breakdown

| Layer | Files | Responsibility |
|---|---|---|
| **UI** | `lib/ui/screens/`, `lib/ui/widgets/` | Flutter screens, chat bubbles, settings panels |
| **State** | `lib/providers/` | Riverpod `StateNotifier`s — chat, server, models, speech |
| **Server Lifecycle** | `lib/providers/server_provider.dart` | Spawns/kills `llama-server.exe` as a child process; health-polls `/health` every 1 s until ready |
| **LLM Client** | `lib/data/services/llama_service.dart` | OpenAI-compatible HTTP client; SSE stream parser for real-time token streaming |
| **RAG / File Extraction** | `lib/core/services/file_extraction_service.dart` | PDF, DOCX, EPUB, Excel, CSV → plain text for context injection |
| **Prompt Engineering** | `lib/core/ai/prompt_builder.dart` | Builds system + user prompt with conversation history and attachments |
| **Vision Pipeline** | `server_provider.dart → startVisionServer()` | Restarts llama-server with `--mmproj` flag; waits for `"status":"ok"` before accepting prompts |
| **Persistence** | `lib/data/repositories/` | SQLite via `sqflite_common_ffi` — stores conversations and messages |

### Fine-tuned Models

Both models were fine-tuned from the **Qwen2.5-3B** base on a multilingual conversational dataset:

- **Linkless-AI-Pro** — text-only fine-tune
- **Linkless-AI-VL** — vision-language fine-tune (requires `mmproj` projector for image understanding)

Quantized to **Q4_K_M** using `llama-quantize` for an optimal quality-vs-size tradeoff on consumer hardware.  
Models available on Hugging Face: [🤗 Linkless-AI-Pro](https://huggingface.co/YOUR_HF_USERNAME/Linkless-AI-Pro) · [🤗 Linkless-AI-VL](https://huggingface.co/YOUR_HF_USERNAME/Linkless-AI-VL)

---

## 🛠️ Section 5 — Build It Yourself (Developer Setup)

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.x | [flutter.dev](https://flutter.dev) |
| Dart SDK | ≥ 3.10 | Bundled with Flutter |
| Visual Studio 2022 | C++ Desktop workload | Required by Flutter Windows |
| CUDA Toolkit *(optional)* | 12.4+ | For GPU acceleration via llama.cpp |
| Git | Any | — |

### 1. Clone the repository

```bash
git clone https://github.com/viraj/linkless_ai.git
cd linkless_ai
```

### 2. Get Flutter dependencies

```bash
flutter pub get
```

### 3. Download models and llama.cpp binaries

```bat
download_models.bat
```

> Edit the `HF_USER` variable in `download_models.bat` to point to the correct Hugging Face username before running.

### 4. Run in debug mode

```bash
flutter run -d windows
```

### 5. Build a release executable

```bash
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\linkless_ai.exe`

### Project Structure

```
linkless_ai/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── ai/             # Prompt builder, token estimator, summary service
│   │   ├── models/         # Attachment data class
│   │   └── services/       # File extraction (PDF, DOCX, EPUB, Excel, CSV)
│   ├── data/
│   │   ├── models/         # Conversation, Message, AppSettings
│   │   ├── repositories/   # SQLite chat repository
│   │   └── services/       # LlamaService (HTTP/SSE client)
│   ├── providers/          # Riverpod — chat, server, model, speech, settings
│   └── ui/
│       ├── screens/        # MainScreen, ModelsScreen, SettingsScreen
│       ├── widgets/        # Chat bubble, sidebar, message input
│       └── components/     # Reusable UI primitives
├── assets/                 # App icons and artwork
├── models/                 # GGUF weights (gitignored — use download_models.bat)
├── llama-cpp/              # llama-server binaries (gitignored — use download_models.bat)
├── download_models.bat     # Bootstrap script
└── pubspec.yaml
```

### Key Dependencies

```yaml
flutter_riverpod: ^2.6.1        # State management
sqflite_common_ffi: ^2.4.0      # SQLite (Windows FFI)
flutter_markdown: ^0.7.7        # Markdown rendering
google_fonts: ^8.0.0            # Typography
bitsdojo_window: ^0.1.6         # Custom window chrome
file_picker: ^10.3.10           # Multi-file attachment picker
syncfusion_flutter_pdf: ^27.1.48  # PDF text extraction
speech_to_text: ^7.3.0          # Windows SAPI voice input
flutter_animate: ^4.5.2         # Micro-animations
```

---

<div align="center">

Built with ❤️ by **Viraj** &nbsp;|&nbsp; [GitHub](https://github.com/viraj) &nbsp;|&nbsp; [Hugging Face](https://huggingface.co/YOUR_HF_USERNAME)

*Linkless AI — because your thoughts shouldn't need a Wi-Fi signal.*

</div>
