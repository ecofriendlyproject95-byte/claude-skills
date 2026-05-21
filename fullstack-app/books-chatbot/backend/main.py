"""
Books Chatbot Backend
────────────────────
Loads the elvinrustam/books-dataset from Kaggle, filters for arts &
philosophy books, and answers user questions about them using Claude.

Architecture:
  User question → keyword search on dataset → top N books as context → Claude → answer

Run:
  cp .env.example .env   # fill in your keys
  pip install -r requirements.txt
  uvicorn main:app --reload --port 8000
"""

import os
import re
import json
import asyncio
from contextlib import asynccontextmanager
from typing import List, Optional

import pandas as pd
import anthropic
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

# ── Config ─────────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
KAGGLE_USERNAME   = os.getenv("KAGGLE_USERNAME", "")
KAGGLE_KEY        = os.getenv("KAGGLE_KEY", "")

# Set Kaggle env vars before importing kagglehub
if KAGGLE_USERNAME and KAGGLE_KEY:
    os.environ["KAGGLE_USERNAME"] = KAGGLE_USERNAME
    os.environ["KAGGLE_KEY"]      = KAGGLE_KEY

ARTS_PHILOSOPHY_KEYWORDS = [
    "philosophy", "art", "artist", "painting", "sculpture", "aesthetics",
    "ethics", "logic", "metaphysics", "epistemology", "existentialism",
    "stoicism", "platonism", "aristotle", "nietzsche", "kant", "hegel",
    "socrates", "plato", "descartes", "spinoza", "hume", "locke", "marx",
    "sartre", "camus", "beauvoir", "foucault", "derrida", "wittgenstein",
    "buddhism", "taoism", "confucius", "renaissance", "baroque", "impressionism",
    "modernism", "contemporary art", "museum", "gallery", "drawing", "design",
    "music theory", "visual art", "creative", "culture", "civilization",
]

TOP_K_RESULTS = 8  # books to pass as context per query

# ── Dataset state ──────────────────────────────────────────────────────────
books_df: Optional[pd.DataFrame] = None
arts_phil_df: Optional[pd.DataFrame] = None


def load_dataset() -> pd.DataFrame:
    """Download and normalise the Kaggle books dataset."""
    import kagglehub
    from kagglehub import KaggleDatasetAdapter

    print("📚 Downloading books dataset from Kaggle…")
    df = kagglehub.load_dataset(
        KaggleDatasetAdapter.PANDAS,
        "elvinrustam/books-dataset",
        "",
    )
    print(f"✅ Loaded {len(df):,} records. Columns: {list(df.columns)}")
    return df


def normalise_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Rename columns to a consistent schema regardless of dataset version."""
    rename_map = {}
    lower_cols = {c.lower().replace(" ", "_"): c for c in df.columns}

    candidates = {
        "title":       ["title", "booktitle", "book_title", "name"],
        "author":      ["author", "bookauthor", "book_author", "authors"],
        "genre":       ["genre", "categories", "category", "subject", "subjects"],
        "description": ["description", "synopsis", "summary", "about", "overview"],
        "rating":      ["rating", "averagerating", "average_rating", "score"],
        "year":        ["year", "yearofpublication", "published_year", "publication_year"],
        "publisher":   ["publisher", "publishing_house"],
        "pages":       ["pages", "num_pages", "pagecount", "page_count"],
        "language":    ["language", "lang"],
    }

    for standard, options in candidates.items():
        for opt in options:
            if opt in lower_cols:
                rename_map[lower_cols[opt]] = standard
                break

    return df.rename(columns=rename_map)


def filter_arts_philosophy(df: pd.DataFrame) -> pd.DataFrame:
    """Keep only rows that look like arts / philosophy books."""
    text_cols = [c for c in ["title", "genre", "description"] if c in df.columns]
    if not text_cols:
        return df  # can't filter, return everything

    mask = pd.Series(False, index=df.index)
    pattern = "|".join(ARTS_PHILOSOPHY_KEYWORDS)

    for col in text_cols:
        col_text = df[col].fillna("").astype(str).str.lower()
        mask = mask | col_text.str.contains(pattern, regex=True, na=False)

    filtered = df[mask].copy()
    print(f"🎨 Arts & philosophy books found: {len(filtered):,}")
    return filtered


def search_books(query: str, df: pd.DataFrame, top_k: int = TOP_K_RESULTS) -> pd.DataFrame:
    """Simple keyword search across title, author, genre, description."""
    words = re.sub(r"[^\w\s]", " ", query.lower()).split()
    if not words:
        return df.head(top_k)

    text_cols = [c for c in ["title", "author", "genre", "description"] if c in df.columns]
    scores = pd.Series(0, index=df.index)

    for col in text_cols:
        col_text = df[col].fillna("").astype(str).str.lower()
        weight = 3 if col == "title" else (2 if col == "author" else 1)
        for word in words:
            scores += col_text.str.contains(re.escape(word), regex=True, na=False).astype(int) * weight

    top_idx = scores.nlargest(top_k).index
    return df.loc[top_idx]


def books_to_context(df: pd.DataFrame) -> str:
    """Serialise a dataframe slice into a readable context block for Claude."""
    if df.empty:
        return "No matching books found in the dataset."

    lines = []
    for i, (_, row) in enumerate(df.iterrows(), 1):
        parts = [f"**Book {i}:**"]
        for field in ["title", "author", "genre", "year", "publisher", "pages", "rating", "language"]:
            val = row.get(field, "")
            if pd.notna(val) and str(val).strip():
                parts.append(f"  {field.capitalize()}: {val}")
        desc = row.get("description", "")
        if pd.notna(desc) and str(desc).strip():
            parts.append(f"  Description: {str(desc)[:300]}…" if len(str(desc)) > 300 else f"  Description: {desc}")
        lines.append("\n".join(parts))

    return "\n\n".join(lines)


# ── Lifespan — load dataset once at startup ────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    global books_df, arts_phil_df
    try:
        raw = await asyncio.get_event_loop().run_in_executor(None, load_dataset)
        books_df = normalise_columns(raw)
        arts_phil_df = filter_arts_philosophy(books_df)
    except Exception as e:
        print(f"⚠️  Dataset load failed: {e}")
        print("   Running without dataset — Claude will answer from general knowledge.")
        books_df = pd.DataFrame()
        arts_phil_df = pd.DataFrame()
    yield


# ── App ────────────────────────────────────────────────────────────────────
app = FastAPI(title="Books Chatbot API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

SYSTEM_PROMPT = """You are an expert librarian and scholar specialising in arts and philosophy books.
You have access to a curated books dataset. When answering questions:

- Reference specific books from the DATASET CONTEXT when relevant
- Include title, author, and a brief reason why the book is relevant
- If asked for recommendations, suggest 3-5 books with short explanations
- Be conversational but knowledgeable — like a passionate librarian
- If a book isn't in the dataset context, you can still mention well-known works from your general knowledge, but flag it as "not in our current catalog"
- Keep responses focused and well-structured using markdown

Always prioritise accuracy over breadth."""


# ── Models ─────────────────────────────────────────────────────────────────
class Message(BaseModel):
    role: str       # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: List[Message] = []


# ── Routes ─────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {
        "status": "ok",
        "total_books": len(books_df) if books_df is not None else 0,
        "arts_philosophy_books": len(arts_phil_df) if arts_phil_df is not None else 0,
    }


@app.get("/books/search")
def search(q: str = "", limit: int = 10):
    if arts_phil_df is None or arts_phil_df.empty:
        raise HTTPException(503, "Dataset not loaded")
    results = search_books(q, arts_phil_df, top_k=limit)
    return results.fillna("").to_dict(orient="records")


@app.post("/chat")
async def chat(req: ChatRequest):
    """Stream a Claude response grounded in the books dataset."""

    # 1. Search dataset for relevant books
    context_text = ""
    if arts_phil_df is not None and not arts_phil_df.empty:
        relevant = search_books(req.message, arts_phil_df)
        context_text = books_to_context(relevant)

    # 2. Build system message with dataset context
    system = SYSTEM_PROMPT
    if context_text:
        system += f"\n\n---\nDATASET CONTEXT (books relevant to this query):\n{context_text}\n---"

    # 3. Build message history
    messages = [
        {"role": m.role, "content": m.content}
        for m in req.history
    ]
    messages.append({"role": "user", "content": req.message})

    # 4. Stream Claude response
    async def generate():
        try:
            with client.messages.stream(
                model="claude-sonnet-4-6",
                max_tokens=1024,
                system=system,
                messages=messages,
            ) as stream:
                for text in stream.text_stream:
                    yield f"data: {json.dumps({'text': text})}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
