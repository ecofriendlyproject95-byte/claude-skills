# Fullstack AI Agents App

Flutter mobile app + NestJS backend + Books chatbot — powered by Claude (Anthropic).

---

## What's inside

```
fullstack-app/
├── backend/               ← NestJS REST API (Node.js)
│   ├── src/
│   │   ├── agents/        ← 20 AI agent personas (catalog + endpoints)
│   │   └── chat/          ← Claude API streaming endpoint
│   ├── package.json
│   └── .env.example
│
├── mobile/                ← Flutter app (iOS + Android)
│   ├── lib/
│   │   ├── screens/       ← Home (agent list) + Chat screen
│   │   ├── widgets/       ← Agent card + Message bubble
│   │   ├── models/        ← Agent + Message data models
│   │   └── services/      ← HTTP + SSE streaming service
│   └── pubspec.yaml
│
├── preview.html           ← Full app preview (open in browser)
├── chat-preview.html      ← Chat screen preview (open in browser)
│
└── books-chatbot/
    ├── backend/           ← Python FastAPI + Kaggle dataset + Claude
    │   ├── main.py
    │   └── requirements.txt
    └── books-chat.html    ← Books chatbot UI (open in browser)
```

---

## Agents included (20 total)

| Domain | Agents |
|---|---|
| Engineering | Senior Engineer, Backend, Frontend, Fullstack |
| Personas | Startup CTO, Solo Founder, Growth Marketer |
| Project Mgmt | Project Manager |
| Design | UX Researcher & Designer |
| Marketing | Content Creator, Demand Gen, AEO Specialist |
| C-Level | CEO, CTO, CMO, CFO Advisors |
| Product | Product Manager, Product Strategist |
| Research | Research Orchestrator |
| Finance | Financial Analyst |

---

## Quick start

### 1. NestJS backend
```bash
cd fullstack-app/backend
cp .env.example .env
npm install
npm run start:dev
```

### 2. Flutter app
```bash
cd fullstack-app/mobile
flutter pub get
flutter run
```

### 3. Browser previews (no install)
- `preview.html` — full app preview
- `chat-preview.html` — chat screen, 5 agents
- `books-chatbot/books-chat.html` — books chatbot

### 4. Books chatbot backend
```bash
cd fullstack-app/books-chatbot/backend
cp .env.example .env
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

## Tech stack
- **Flutter** — cross-platform mobile (iOS + Android)
- **NestJS** — Node.js backend framework  
- **FastAPI** — Python backend for books chatbot
- **Claude API** — Anthropic claude-sonnet-4-6 model
- **Kaggle** — `elvinrustam/books-dataset` (arts & philosophy filter)
