# AgentsCouncil

A multi-platform AI debate system where configurable AI agents (OpenAI, Anthropic, Gemini) discuss topics, vote through rounds, and reach consensus.

## Features

- **Multi-Agent Council**: Configure debates with AI agents from OpenAI, Anthropic, and Google Gemini
- **Role-Based Personas**: Built-in expert roles (Investment Advisor, PR Expert, Politics Expert, etc.)
- **Round-Based Debates**: Agents discuss and vote each round until consensus or round limit
- **Smart Summarization**: Moderator agent generates structured summaries with Pro vs Against highlights
- **Cross-Platform**: macOS, Windows, iOS, Android (macOS first)

## Project Structure

```
AgentsCouncil/
├── backend/          # Python FastAPI server
├── frontend/         # Flutter app
└── docs/            # Documentation
```

## Quick Start

### Prerequisites

- Python 3.11+
- Flutter 3.x
- API keys for AI providers

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env      # Add your API keys
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d macos
```

## Configuration

Copy `.env.example` to `.env` and add your API keys:

```
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
GEMINI_API_KEY=your_gemini_key
```

## License

MIT
