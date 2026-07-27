# ============================================================================
#  lazy-tube Setup Script
#  Creates complete project structure at D:\GitHub\lazy-tube
#  Run: powershell -ExecutionPolicy Bypass -File setup.ps1
# ============================================================================

$ErrorActionPreference = "Stop"
$root = "D:\GitHub\lazy-tube"

Write-Host "`n=== lazy-tube Project Bootstrapper ===" -ForegroundColor Cyan
Write-Host "Target: $root`n" -ForegroundColor Yellow

# ---------------------------------------------------------------------------
# 1. CREATE FOLDER STRUCTURE
# ---------------------------------------------------------------------------
$folders = @(
    "backend\api",
    "backend\skills",
    "backend\core",
    "backend\data",
    "frontend\src\api",
    "frontend\src\components",
    "frontend\public",
    "config",
    "data",
    "output",
    "logs"
)

foreach ($f in $folders) {
    $path = Join-Path $root $f
    New-Item -ItemType Directory -Force -Path $path | Out-Null
}
Write-Host "[OK] Folder structure created" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. HELPER: write file without BOM
# ---------------------------------------------------------------------------
function Write-File([string]$RelPath, [string]$Content) {
    $full = Join-Path $root $RelPath
    $dir = Split-Path $full -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    # ------------------------------------------------------------------
    # WRITE FILE (UTF-8, no BOM)
    # ------------------------------------------------------------------
    [System.IO.File]::WriteAllText($full, $Content, [System.Text.UTF8Encoding]::new($false))

    # ------------------------------------------------------------------
    # VERIFY
    # ------------------------------------------------------------------
    if (Test-Path $full) {
        $size = (Get-Item $full).Length
        Write-Host "  + $RelPath" -ForegroundColor Green -NoNewline
        Write-Host "  ($size bytes)" -ForegroundColor DarkGray
        return $true
    }
    else {
        Write-Host "  [ERROR] Failed to create $RelPath" -ForegroundColor Red
        return $false
    }
}

# ===========================================================================
# 3. BACKEND PYTHON FILES
# ===========================================================================

# ---------- backend/main.py ----------
$mainPy = @'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from api.generate import router as generate_router
from api.review import router as review_router
from api.upload import router as upload_router
from api.youtube_helpers import router as youtube_router

app = FastAPI(title="lazy-tube", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000", "app://."],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(generate_router, prefix="/api")
app.include_router(review_router, prefix="/api")
app.include_router(upload_router, prefix="/api")
app.include_router(youtube_router, prefix="/api")


@app.get("/")
def root():
    return {"app": "lazy-tube", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
'@

# ---------- backend/__init__.py ----------
$backendInit = ""

# ---------- backend/api/__init__.py ----------
$apiInit = ""

# ---------- backend/skills/__init__.py ----------
$skillsInit = ""

# ---------- backend/core/__init__.py ----------
$coreInit = ""

# ---------- backend/core/ollama_client.py ----------
$ollamaPy = @'
import httpx
import yaml
import os
from typing import Optional


class OllamaClient:
    def __init__(self, config_path: str = None):
        if config_path is None:
            base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            config_path = os.path.join(base, "..", "config", "ollama_config.yaml")
        with open(config_path, "r", encoding="utf-8") as f:
            self.config = yaml.safe_load(f)["ollama"]
        self.base_url = self.config["base_url"]
        self.models = self.config["models"]

    def get_model(self, task: str) -> str:
        assignment = self.config.get("assignment", {})
        return assignment.get(task, self.models["balanced"])

    def generate(self, prompt: str, model: Optional[str] = None,
                 temperature: float = 0.7, system: Optional[str] = None) -> str:
        model = model or self.models["balanced"]
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": temperature},
        }
        if system:
            payload["system"] = system
        try:
            with httpx.Client(timeout=180) as client:
                r = client.post(f"{self.base_url}/api/generate", json=payload)
                r.raise_for_status()
                return r.json()["response"].strip()
        except Exception as e:
            return f"[ERROR calling Ollama: {e}]"

    def chat(self, messages: list, model: Optional[str] = None) -> str:
        model = model or self.models["balanced"]
        payload = {"model": model, "messages": messages, "stream": False}
        try:
            with httpx.Client(timeout=180) as client:
                r = client.post(f"{self.base_url}/api/chat", json=payload)
                r.raise_for_status()
                return r.json()["message"]["content"].strip()
        except Exception as e:
            return f"[ERROR calling Ollama: {e}]"
'@

# ---------- backend/core/brand_loader.py ----------
$brandPy = @'
import yaml
import os


def load_brand(path: str = None) -> dict:
    if path is None:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(base, "..", "data", "brand_profile.yaml")
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def build_brand_context(brand: dict) -> str:
    ch = brand.get("channel", {})
    vis = brand.get("visual_brand", {})
    style = brand.get("title_style", {})
    parts = [
        f"Channel name: {ch.get('name', 'Unknown')}",
        f"Tone: {ch.get('tone', 'neutral')}",
        f"Audience: {ch.get('audience', 'general viewers')}",
        f"Primary color: {vis.get('primary_color', 'N/A')}",
        f"Visual mood: {vis.get('mood', 'modern')}",
        f"Title pattern: {style.get('pattern', '{topic}: {hook}')}",
        f"Title examples: {', '.join(style.get('examples', []))}",
    ]
    return "\n".join(parts)
'@

# ---------- backend/core/config_compiler.py ----------
$compilerPy = @'
def compile_youtube_payload(metadata: dict, defaults: dict, scheduled: str = None) -> dict:
    """Compile final YouTube API payload from generated metadata."""
    snippet = {
        "title": metadata.get("title", "")[:100],
        "description": metadata.get("description", "")[:5000],
        "tags": metadata.get("tags", [])[:30] or [],
        "categoryId": str(metadata.get("category_id", 22)),
    }
    if metadata.get("default_language"):
        snippet["defaultLanguage"] = metadata["default_language"]

    status = {
        "privacyStatus": defaults.get("visibility", "private"),
        "selfDeclaredMadeForKids": defaults.get("made_for_kids", False),
        "embeddable": defaults.get("embeddable", True),
        "license": defaults.get("license", "youtube"),
    }
    if scheduled:
        status["publishAt"] = scheduled
        status["privacyStatus"] = "private"

    return {"snippet": snippet, "status": status}
'@

# ---------- backend/core/youtube_client.py ----------
$ytPy = @'
import os
import pickle
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
import yaml

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly",
]


class YouTubeClient:
    def __init__(self, config_path: str = None):
        if config_path is None:
            base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            config_path = os.path.join(base, "..", "config", "youtube_config.yaml")
        with open(config_path, "r", encoding="utf-8") as f:
            self.config = yaml.safe_load(f)["youtube"]
        self.creds = None
        self.service = None

    def _token_path(self) -> str:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(base, "..", "data", "youtube_token.pickle")

    def _secrets_path(self) -> str:
        cfg = self.config.get("client_secrets_file", "data/client_secrets.json")
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.normpath(os.path.join(base, "..", cfg))

    def authenticate(self):
        """Desktop OAuth flow. Opens browser, stores token locally."""
        token_path = self._token_path()
        if os.path.exists(token_path):
            with open(token_path, "rb") as f:
                self.creds = pickle.load(f)

        if not self.creds or not self.creds.valid:
            if self.creds and self.creds.expired and self.creds.refresh_token:
                self.creds.refresh(Request())
            else:
                secrets = self._secrets_path()
                if not os.path.exists(secrets):
                    raise FileNotFoundError(
                        f"client_secrets.json not found at: {secrets}\n"
                        f"See api-guide.md for setup instructions."
                    )
                flow = InstalledAppFlow.from_client_secrets_file(secrets, SCOPES)
                self.creds = flow.run_local_server(port=8080)

            with open(token_path, "wb") as f:
                pickle.dump(self.creds, f)

        self.service = build("youtube", "v3", credentials=self.creds)
        return self.service

    def get_channel_info(self) -> dict:
        if not self.service:
            self.authenticate()
        resp = self.service.channels().list(
            part="snippet,contentDetails,statistics", mine=True
        ).execute()
        items = resp.get("items", [])
        if not items:
            return {}
        ch = items[0]
        return {
            "channel_id": ch["id"],
            "title": ch["snippet"]["title"],
            "thumb": ch["snippet"]["thumbnails"]["default"]["url"],
            "subs": ch["statistics"].get("subscriberCount", "0"),
            "uploads_playlist": ch["contentDetails"]["relatedPlaylists"]["uploads"],
        }

    def list_playlists(self) -> list:
        if not self.service:
            self.authenticate()
        resp = self.service.playlists().list(
            part="snippet,contentDetails", mine=True, maxResults=50
        ).execute()
        return [
            {"id": p["id"], "title": p["snippet"]["title"],
             "count": p["contentDetails"]["itemCount"]}
            for p in resp.get("items", [])
        ]

    def list_recent_thumbnails(self, max_results: int = 5) -> list:
        """Get recent video thumbnails for style reference."""
        try:
            if not self.service:
                self.authenticate()
            ch = self.get_channel_info()
            if not ch:
                return []
            resp = self.service.playlistItems().list(
                part="contentDetails",
                playlistId=ch["uploads_playlist"],
                maxResults=max_results,
            ).execute()
            video_ids = [i["contentDetails"]["videoId"] for i in resp.get("items", [])]
            if not video_ids:
                return []
            vids = self.service.videos().list(
                part="snippet", id=",".join(video_ids)
            ).execute()
            out = []
            for v in vids.get("items", []):
                thumbs = v["snippet"].get("thumbnails", {})
                url = (thumbs.get("maxres") or thumbs.get("high") or
                       thumbs.get("medium") or thumbs.get("default", {})).get("url", "")
                out.append({"title": v["snippet"]["title"], "thumbnail": url})
            return out
        except Exception as e:
            print(f"Could not fetch reference thumbnails: {e}")
            return []

    def upload_video(self, video_path: str, payload: dict,
                     thumbnail_path: str = None) -> dict:
        if not self.service:
            self.authenticate()

        body = {"snippet": payload["snippet"], "status": payload["status"]}
        media = MediaFileUpload(
            video_path, mimetype="video/*", resumable=True,
            chunksize=10 * 1024 * 1024,
        )

        insert_resp = self.service.videos().insert(
            part="snippet,status", body=body, media_body=media
        )
        video = None
        while video is None:
            status, video = insert_resp.next_chunk()
            if status:
                pct = int(status.progress() * 100)
                print(f"  Upload progress: {pct}%")

        video_id = video["id"]
        result = {"video_id": video_id, "url": f"https://youtu.be/{video_id}"}

        if thumbnail_path and os.path.exists(thumbnail_path):
            try:
                self.service.thumbnails().set(
                    videoId=video_id,
                    media_body=MediaFileUpload(thumbnail_path, mimetype="image/*"),
                ).execute()
                result["thumbnail_set"] = True
            except Exception as e:
                result["thumbnail_error"] = str(e)

        return result
'@

# ---------- backend/skills/title_skill.py ----------
$titlePy = @'
from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class TitleSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)
        style = brand.get("title_style", {})
        pattern = style.get("pattern", "{topic}: {hook}")
        examples = ", ".join(style.get("examples", [])) or "N/A"

        system = "You are an expert YouTube title creator. Output ONLY the titles, one per line. No numbering, no commentary."
        prompt = f"""Channel brand:
{brand_ctx}

Title pattern to follow: {pattern}
Reference examples: {examples}

Generate 5 title options for this video:
{context}

Rules:
- Under 100 characters each
- Include primary keyword from the topic
- Mix styles: curiosity, how-to, listicle, news
- No clickbait, no misleading claims
- Match the channel tone exactly

Output 5 titles, one per line:"""

        model = self.ollama.get_model("title")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.8)
        titles = []
        for line in response.split("\n"):
            t = line.strip().lstrip("0123456789.-) ").strip()
            if t and len(t) > 5:
                titles.append(t[:100])
        return {"titles": titles[:5], "selected": titles[0] if titles else ""}
'@

# ---------- backend/skills/description_skill.py ----------
$descPy = @'
from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class DescriptionSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)
        template = brand.get("description_template", "")
        hashtags = brand.get("hashtags_fixed", [])
        about = brand.get("channel", {}).get("about", "")

        system = "You write YouTube descriptions that are engaging, SEO-friendly, and match the channel voice exactly."
        prompt = f"""Channel brand:
{brand_ctx}

Title: {title}
Video context: {context}

Template to follow:
{template if template else "Hook (2 lines) | Summary with bullets | Timestamps placeholder | Links | About | Hashtags"}

About this channel: {about}
Fixed channel hashtag: #{hashtags[0] if hashtags else 'channel'}

Write a complete YouTube description:
- First 2 lines = hook (visible above "show more")
- Then summary with 3-5 bullet points
- Add timestamp placeholder line: "0:00 Intro" etc.
- Brief about-channel blurb (1-2 lines)
- 3-5 relevant hashtags at the end (include the fixed channel hashtag)

Output ONLY the description, in markdown:"""

        model = self.ollama.get_model("description")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.7)
        return {"description": response.strip()}
'@

# ---------- backend/skills/tag_skill.py ----------
$tagPy = @'
from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class TagSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)

        system = "You generate YouTube tags for maximum discoverability."
        prompt = f"""Channel: {brand.get('channel', {}).get('name', '')}
Brand context:
{brand_ctx}

Title: {title}
Context: {context}

Generate 20-25 YouTube tags:
- Mix of broad (1-2 words) and long-tail (3-5 words)
- Include variations: singular/plural, with/without year
- Include common related searches people would type
- Lowercase, comma-separated, NO # symbol

Output ONLY the comma-separated tags:"""

        model = self.ollama.get_model("tags")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.5)
        text = response.replace("\n", ",")
        tags = [t.strip().lstrip("#").strip()
                for t in text.split(",") if t.strip()]
        return {"tags": tags[:30]}
'@

# ---------- backend/skills/category_skill.py ----------
$catPy = @'
from core.ollama_client import OllamaClient

YOUTUBE_CATEGORIES = {
    1: "Film & Animation", 2: "Autos & Vehicles", 10: "Music",
    15: "Pets & Animals", 17: "Sports", 19: "Travel & Events",
    20: "Gaming", 21: "Videoblogging", 22: "People & Blogs",
    23: "Comedy", 24: "Entertainment", 25: "News & Politics",
    26: "Howto & Style", 27: "Education", 28: "Science & Technology",
    29: "Nonprofits & Activism",
}


class CategorySkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        cats = "\n".join([f"{k}: {v}" for k, v in YOUTUBE_CATEGORIES.items()])
        default = brand.get("category_default", 22)

        system = "You classify YouTube videos into the correct category. Respond with ONLY a number."
        prompt = f"""Title: {title}
Context: {context}

Available YouTube categories:
{cats}

Output ONLY the category ID number:"""

        model = self.ollama.get_model("category")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.1)
        try:
            digits = "".join(c for c in response if c.isdigit())[:2]
            cat_id = int(digits) if digits else default
            if cat_id not in YOUTUBE_CATEGORIES:
                cat_id = default
        except Exception:
            cat_id = default

        return {
            "category_id": cat_id,
            "category_name": YOUTUBE_CATEGORIES[cat_id],
        }
'@

# ---------- backend/skills/hashtag_skill.py ----------
$hashPy = @'
from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class HashtagSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict) -> dict:
        brand_ctx = build_brand_context(brand)
        fixed = brand.get("hashtags_fixed", [])

        system = "You create YouTube hashtags."
        prompt = f"""Channel brand:
{brand_ctx}

Title: {title}
Context: {context}

Generate exactly 3 hashtags specific to THIS video topic.
Output WITHOUT the # symbol, one per line, no numbering:"""

        model = self.ollama.get_model("hashtag")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.6)
        tags = [t.strip().replace("#", "").strip()
                for t in response.split("\n") if t.strip()]
        tags = tags[:3]
        all_tags = [f"#{t}" for t in fixed] + [f"#{t}" for t in tags]
        return {"hashtags": all_tags}
'@

# ---------- backend/skills/thumbnail_prompt_skill.py ----------
$thumbPy = @'
from core.ollama_client import OllamaClient
from core.brand_loader import build_brand_context


class ThumbnailPromptSkill:
    def __init__(self, ollama: OllamaClient):
        self.ollama = ollama

    def generate(self, context: str, title: str, brand: dict,
                 ref_thumbnails: list = None) -> dict:
        brand_ctx = build_brand_context(brand)
        vis = brand.get("visual_brand", {})

        ref_section = ""
        if ref_thumbnails:
            ref_section = "\nReference style from your recent successful thumbnails:\n" + \
                "\n".join([f"- {r.get('title', '')}" for r in ref_thumbnails[:3]]) + \
                "\nMatch this visual style.\n"

        system = """You are an expert YouTube thumbnail designer. You create prompts optimized for Google Nano Banana (Gemini 2.5 Flash Image). Your prompts are vivid, specific, and produce scroll-stopping 16:9 images."""

        prompt = f"""Channel brand:
{brand_ctx}

Visual brand:
- Primary color: {vis.get("primary_color", "cyan")}
- Secondary: {vis.get("secondary_color", "dark blue")}
- Mood: {vis.get("mood", "modern")}
- Text font: {vis.get("font_title", "bold sans-serif")}

Video title: {title}
Context: {context}
{ref_section}

Generate 3 thumbnail concepts as image prompts for Google Nano Banana.

For each concept output EXACTLY this format:

Concept [number]:
Prompt: [vivid cinematic 16:9 image prompt, no text in image, photorealistic, 8K detail]
TextOverlay: [3-5 words ALL CAPS for headline text]
Composition: [where elements are placed]
Mood: [emotion/feeling]
Colors: [3 hex colors]

Concept 1:
Prompt:"""

        model = self.ollama.get_model("thumbnail")
        response = self.ollama.generate(prompt, model=model,
                                        system=system, temperature=0.9)
        return {
            "raw_response": response,
            "prompts": self._parse_concepts(response),
        }

    def _parse_concepts(self, text: str) -> list:
        concepts = []
        blocks = text.split("Concept ")
        for block in blocks[1:]:
            concept = {"text_overlay": "", "prompt": "",
                       "composition": "", "mood": "", "colors": ""}
            current = "prompt"
            for line in block.split("\n"):
                line = line.strip()
                low = line.lower()
                if low.startswith("prompt:"):
                    current = "prompt"
                    concept["prompt"] = line.split(":", 1)[1].strip()
                elif low.startswith("textoverlay:") or low.startswith("text overlay:"):
                    current = "text_overlay"
                    concept["text_overlay"] = line.split(":", 1)[1].strip()
                elif low.startswith("composition:"):
                    current = "composition"
                    concept["composition"] = line.split(":", 1)[1].strip()
                elif low.startswith("mood:"):
                    current = "mood"
                    concept["mood"] = line.split(":", 1)[1].strip()
                elif low.startswith("colors:"):
                    current = "colors"
                    concept["colors"] = line.split(":", 1)[1].strip()
                elif line and not line[0].isdigit():
                    if current and concept.get(current) is not None:
                        concept[current] = (concept[current] + " " + line).strip()
            if concept["prompt"] and len(concept["prompt"]) > 10:
                concepts.append(concept)
        return concepts[:3]
'@

# ---------- backend/api/generate.py ----------
$genApiPy = @'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import asyncio

from skills.title_skill import TitleSkill
from skills.description_skill import DescriptionSkill
from skills.tag_skill import TagSkill
from skills.category_skill import CategorySkill
from skills.hashtag_skill import HashtagSkill
from skills.thumbnail_prompt_skill import ThumbnailPromptSkill
from core.ollama_client import OllamaClient
from core.brand_loader import load_brand
from core.youtube_client import YouTubeClient

router = APIRouter()


class GenerateRequest(BaseModel):
    context: str
    brand_path: str = None
    include_thumbnail: bool = True


@router.post("/generate")
async def generate_metadata(req: GenerateRequest):
    if not req.context.strip():
        raise HTTPException(400, "Context cannot be empty")

    brand = load_brand(req.brand_path)
    ollama = OllamaClient()

    ref_thumbs = []
    if req.include_thumbnail:
        try:
            yt = YouTubeClient()
            ref_thumbs = yt.list_recent_thumbnails(max_results=3)
        except Exception as e:
            print(f"Could not fetch reference thumbnails: {e}")

    title_skill = TitleSkill(ollama)
    title_result = title_skill.generate(req.context, brand)
    selected_title = title_result.get("selected", "")

    desc_skill = DescriptionSkill(ollama)
    tag_skill = TagSkill(ollama)
    cat_skill = CategorySkill(ollama)
    hash_skill = HashtagSkill(ollama)
    thumb_skill = ThumbnailPromptSkill(ollama)

    results = await asyncio.gather(
        asyncio.to_thread(desc_skill.generate, req.context, selected_title, brand),
        asyncio.to_thread(tag_skill.generate, req.context, selected_title, brand),
        asyncio.to_thread(cat_skill.generate, req.context, selected_title, brand),
        asyncio.to_thread(hash_skill.generate, req.context, selected_title, brand),
        asyncio.to_thread(thumb_skill.generate, req.context, selected_title, brand, ref_thumbs),
    )

    return {
        "title_options": title_result["titles"],
        "selected_title": selected_title,
        "description": results[0]["description"],
        "tags": results[1]["tags"],
        "category_id": results[2]["category_id"],
        "category_name": results[2]["category_name"],
        "hashtags": results[3]["hashtags"],
        "thumbnail_prompts": results[4]["prompts"],
        "thumbnail_raw": results[4]["raw_response"],
    }


class RegenerateRequest(BaseModel):
    field: str
    context: str
    selected_title: str = None
    brand_path: str = None


@router.post("/regenerate")
async def regenerate_field(req: RegenerateRequest):
    brand = load_brand(req.brand_path)
    ollama = OllamaClient()
    title = req.selected_title or ""

    if req.field == "title":
        result = TitleSkill(ollama).generate(req.context, brand)
        return {"options": result["titles"]}
    elif req.field == "description":
        result = DescriptionSkill(ollama).generate(req.context, title, brand)
        return {"description": result["description"]}
    elif req.field == "tags":
        result = TagSkill(ollama).generate(req.context, title, brand)
        return {"tags": result["tags"]}
    elif req.field == "hashtags":
        result = HashtagSkill(ollama).generate(req.context, title, brand)
        return {"hashtags": result["hashtags"]}
    elif req.field == "thumbnail":
        result = ThumbnailPromptSkill(ollama).generate(req.context, title, brand)
        return {"prompts": result["prompts"], "raw": result["raw_response"]}
    else:
        raise HTTPException(400, f"Unknown field: {req.field}")
'@

# ---------- backend/api/review.py ----------
$reviewPy = @'
from fastapi import APIRouter
from pydantic import BaseModel
import json
import os
from datetime import datetime

router = APIRouter()
LOG_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "logs", "review_log.json")


class ReviewRequest(BaseModel):
    metadata: dict
    status: str = "reviewed"


@router.post("/review")
async def save_review(req: ReviewRequest):
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    log = []
    if os.path.exists(LOG_PATH):
        try:
            with open(LOG_PATH, "r", encoding="utf-8") as f:
                log = json.load(f)
        except Exception:
            log = []
    entry = {
        "timestamp": datetime.now().isoformat(),
        "status": req.status,
        "metadata": req.metadata,
    }
    log.append(entry)
    with open(LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)
    return {"saved": True, "total": len(log)}


@router.get("/review")
async def list_reviews():
    if not os.path.exists(LOG_PATH):
        return {"reviews": []}
    with open(LOG_PATH, "r", encoding="utf-8") as f:
        return {"reviews": json.load(f)}
'@

# ---------- backend/api/upload.py ----------
$uploadPy = @'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import os
import json
from datetime import datetime

from core.youtube_client import YouTubeClient
from core.config_compiler import compile_youtube_payload
from core.brand_loader import load_brand

router = APIRouter()
LOG_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "logs", "publish_log.json")


class UploadRequest(BaseModel):
    video_path: str
    metadata: dict
    thumbnail_path: str = None
    scheduled_publish: str = None


@router.post("/upload")
async def upload_video(req: UploadRequest):
    if not os.path.exists(req.video_path):
        raise HTTPException(404, f"Video file not found: {req.video_path}")

    brand = load_brand()
    defaults = {
        "visibility": "private",
        "made_for_kids": brand.get("youtube_defaults", {}).get("made_for_kids", False),
        "embeddable": brand.get("youtube_defaults", {}).get("embeddable", True),
        "license": brand.get("youtube_defaults", {}).get("license", "youtube"),
    }

    payload = compile_youtube_payload(req.metadata, defaults, req.scheduled_publish)

    try:
        yt = YouTubeClient()
        yt.authenticate()
        result = yt.upload_video(req.video_path, payload, req.thumbnail_path)
    except Exception as e:
        raise HTTPException(500, f"Upload failed: {e}")

    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    log = []
    if os.path.exists(LOG_PATH):
        try:
            with open(LOG_PATH, "r", encoding="utf-8") as f:
                log = json.load(f)
        except Exception:
            log = []
    log.append({
        "timestamp": datetime.now().isoformat(),
        "video_id": result.get("video_id"),
        "url": result.get("url"),
        "title": req.metadata.get("title"),
    })
    with open(LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)

    return result


@router.get("/upload/log")
async def get_publish_log():
    if not os.path.exists(LOG_PATH):
        return {"log": []}
    with open(LOG_PATH, "r", encoding="utf-8") as f:
        return {"log": json.load(f)}
'@

# ---------- backend/api/youtube_helpers.py ----------
$ytHelperPy = @'
from fastapi import APIRouter
from core.youtube_client import YouTubeClient

router = APIRouter()


@router.get("/youtube/channel")
async def get_channel():
    try:
        yt = YouTubeClient()
        return yt.get_channel_info()
    except Exception as e:
        return {"error": str(e)}


@router.get("/youtube/playlists")
async def get_playlists():
    try:
        yt = YouTubeClient()
        return {"playlists": yt.list_playlists()}
    except Exception as e:
        return {"error": str(e)}


@router.get("/youtube/recent-thumbnails")
async def recent_thumbnails(count: int = 5):
    try:
        yt = YouTubeClient()
        return {"thumbnails": yt.list_recent_thumbnails(count)}
    except Exception as e:
        return {"error": str(e)}


@router.post("/youtube/authenticate")
async def authenticate():
    try:
        yt = YouTubeClient()
        yt.authenticate()
        return {"authenticated": True}
    except Exception as e:
        return {"authenticated": False, "error": str(e)}
'@

# ===========================================================================
# 4. CONFIG FILES
# ===========================================================================

# ---------- config/youtube_config.yaml ----------
$ytYaml = @'
youtube:
  client_secrets_file: "../data/client_secrets.json"
  token_file: "../data/youtube_token.pickle"
  default_visibility: "private"
  default_category_id: 22

upload:
  chunk_size_mb: 10
  max_retries: 5
  retry_backoff: exponential
'@

# ---------- config/ollama_config.yaml ----------
$ollamaYaml = @'
ollama:
  base_url: "http://localhost:11434"
  models:
    fast: "phi3:mini"
    balanced: "llama3.1"
    quality: "mistral"
  assignment:
    title: "llama3.1"
    description: "llama3.1"
    tags: "llama3.1"
    category: "llama3.1"
    hashtag: "llama3.1"
    thumbnail: "mistral"
'@

# ---------- data/brand_profile.yaml ----------
$brandYaml = @'
# ============================================================
#  YOUR BRAND PROFILE
#  Edit this to match your channel identity.
#  lazy-tube uses this to keep all videos uniform.
# ============================================================

channel:
  name: "Your Channel Name"
  tone: "informative, friendly, slightly humorous"
  audience: "tech enthusiasts, developers, learners"
  about: "We simplify tech topics for curious minds."

visual_brand:
  primary_color: "#00D4FF"
  secondary_color: "#1A1A2E"
  accent_color: "#FF006E"
  font_title: "Montserrat Bold"
  font_subtitle: "Inter"
  logo_position: "bottom-right"
  mood: "modern, clean, futuristic"

title_style:
  pattern: "{topic}: {hook}"
  emoji_usage: "minimal, max 1 per title"
  caps_usage: "selective, for emphasis only"
  examples:
    - "Rust is Eating JavaScript: Heres Why"
    - "5 Python Tricks I Wish I Knew Earlier"
    - "GPT-5 Just Changed Everything"

description_template: |
  {hook_2_lines}

  In this video:
  {bullets}

  Timestamps:
  0:00 Intro
  0:30 Topic 1
  {more_chapters}

  Links:
  {links}

  --------------------
  About: {about}
  {hashtags}

tag_patterns:
  - "{topic}"
  - "{topic} tutorial"
  - "{topic} 2024"

hashtags_fixed:
  - "YourChannelTag"

category_default: 28

youtube_defaults:
  visibility: "private"
  made_for_kids: false
  embeddable: true
  license: "youtube"

# Channel Bracket System: same channel, different series
# Each bracket can override visual style for topic-specific videos
channel_bracket_system: []
# Example:
#   - topic: "AI & Machine Learning"
#     playlist_name: "AI Weekly"
#     visual_mood: "futuristic, neon, dark backgrounds"
#   - topic: "Web Development"
#     playlist_name: "Web Dev Tips"
#     visual_mood: "clean, code-on-screen, light backgrounds"
'@

# ===========================================================================
# 5. ROOT CONFIG FILES
# ===========================================================================

# ---------- requirements.txt ----------
$reqTxt = @'
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.0
httpx==0.26.0
pyyaml==6.0.1
google-api-python-client==2.111.0
google-auth-oauthlib==1.2.0
google-auth-httplib2==0.2.0
'@

# ---------- .gitignore ----------
$gitignore = @'
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.venv/
venv/
env/

# Node
node_modules/
dist/
.vite/

# Secrets (NEVER commit these)
data/youtube_token.pickle
data/client_secrets.json
.env
.env.local

# Logs & outputs
logs/
output/
*.log

# OS
.DS_Store
Thumbs.db
'@

# ---------- start.ps1 ----------
$startPs1 = @'
# ============================================================
#  lazy-tube Starter
#  Starts backend + frontend in separate windows
# ============================================================

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "Starting lazy-tube..." -ForegroundColor Cyan
Write-Host "  Backend:  http://localhost:8000" -ForegroundColor Gray
Write-Host "  Frontend: http://localhost:5173 (Electron window opens automatically)`n" -ForegroundColor Gray

# --- Backend (FastAPI) ---
$backendCmd = "cd '$root\backend'; " +
    "if (Test-Path .venv) { .\.venv\Scripts\Activate.ps1 } else { python -m venv .venv; .\.venv\Scripts\Activate.ps1; pip install -r ..\requirements.txt }; " +
    "python main.py"

Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd `
    -WindowTitle "lazy-tube Backend" -WorkingDirectory "$root\backend"

# --- Frontend (Vite + Electron) ---
$frontendCmd = "cd '$root\frontend'; " +
    "if (-not (Test-Path node_modules)) { npm install }; " +
    "npm run dev"

Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCmd `
    -WindowTitle "lazy-tube Frontend" -WorkingDirectory "$root\frontend"

Write-Host "`n[OK] Both services launched. Watch the new windows for output." -ForegroundColor Green
Write-Host "     The Electron window will appear once Vite is ready.`n" -ForegroundColor Green
'@

# ===========================================================================
# 6. FRONTEND - PACKAGE & CONFIG
# ===========================================================================

# ---------- frontend/package.json ----------
$pkgJson = @'
{
  "name": "lazy-tube-frontend",
  "version": "0.1.0",
  "main": "main.js",
  "scripts": {
    "dev": "concurrently -k \"vite\" \"wait-on http://localhost:5173 && cross-env VITE_DEV_SERVER_URL=http://localhost:5173 electron .\"",
    "vite": "vite",
    "electron": "electron .",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "autoprefixer": "^10.4.0",
    "concurrently": "^8.2.0",
    "cross-env": "^7.0.3",
    "electron": "^27.0.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.4.0",
    "vite": "^5.0.0",
    "wait-on": "^7.2.0"
  }
}
'@

# ---------- frontend/vite.config.js ----------
$viteConfig = @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
    },
  },
  base: "./",
});
'@

# ---------- frontend/tailwind.config.js ----------
$twConfig = @'
/** @type {import("tailwindcss").Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#00D4FF",
        secondary: "#1A1A2E",
        accent: "#FF006E",
        surface: "#0f0f17",
      },
    },
  },
  plugins: [],
};
'@

# ---------- frontend/postcss.config.js ----------
$postcssConfig = @'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
'@

# ---------- frontend/index.html ----------
$indexHtml = @'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>lazy-tube</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@

# ---------- frontend/main.js (Electron main) ----------
$electronMain = @'
const { app, BrowserWindow } = require("electron");
const path = require("path");

function createWindow() {
  const win = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1100,
    minHeight: 700,
    backgroundColor: "#0f0f17",
    title: "lazy-tube",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (process.env.VITE_DEV_SERVER_URL) {
    win.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    win.loadFile(path.join(__dirname, "dist", "index.html"));
  }
}

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
'@

# ---------- frontend/preload.js ----------
$preloadJs = @'
const { contextBridge } = require("electron");
contextBridge.exposeInMainWorld("electronAPI", {
  // Reserved for future IPC needs
  platform: process.platform,
});
'@

# ---------- frontend/.gitignore ----------
$feGitignore = @"
node_modules
dist
.env
.vite
"@

# ===========================================================================
# 7. FRONTEND - REACT SOURCE
# ===========================================================================

# ---------- frontend/src/main.jsx ----------
$feMain = @'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@

# ---------- frontend/src/index.css ----------
$feCss = @'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: #0f0f17;
  color: #e5e5e5;
}

* {
  box-sizing: border-box;
}

button {
  font-family: inherit;
}

input, textarea, select {
  font-family: inherit;
}
'@

# ---------- frontend/src/api/client.js ----------
$apiClient = @'
const BASE = "/api";

async function request(path, options = {}) {
  const res = await fetch(BASE + path, {
    headers: { "Content-Type": "application/json" },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(err.detail || "Request failed");
  }
  return res.json();
}

export const api = {
  generate: (context) =>
    request("/generate", { method: "POST", body: { context } }),

  regenerate: (field, context, selectedTitle) =>
    request("/regenerate", {
      method: "POST",
      body: { field, context, selected_title: selectedTitle },
    }),

  review: (metadata, status = "reviewed") =>
    request("/review", { method: "POST", body: { metadata, status } }),

  upload: (videoPath, metadata, thumbnailPath = null) =>
    request("/upload", {
      method: "POST",
      body: { video_path: videoPath, metadata, thumbnail_path: thumbnailPath },
    }),

  channel: () => request("/youtube/channel"),
  playlists: () => request("/youtube/playlists"),
  recentThumbs: (count = 5) =>
    request(`/youtube/recent-thumbnails?count=${count}`),
  auth: () => request("/youtube/authenticate", { method: "POST" }),
  publishLog: () => request("/upload/log"),
};
'@

# ---------- frontend/src/App.jsx ----------
$appJsx = @'
import { useState } from "react";
import ContextInput from "./components/ContextInput";
import ReviewEditor from "./components/ReviewEditor";
import PublishLog from "./components/PublishLog";

export default function App() {
  const [step, setStep] = useState("input");
  const [context, setContext] = useState("");
  const [metadata, setMetadata] = useState(null);
  const [loading, setLoading] = useState(false);

  return (
    <div className="min-h-screen p-6">
      <header className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-primary">lazy-tube</h1>
        <nav className="flex gap-2">
          <button
            onClick={() => setStep("input")}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "input"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700"
            }`}
          >
            1. Create
          </button>
          <button
            onClick={() => metadata && setStep("review")}
            disabled={!metadata}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "review"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700 disabled:opacity-40"
            }`}
          >
            2. Review
          </button>
          <button
            onClick={() => setStep("log")}
            className={`px-4 py-1.5 rounded text-sm font-medium transition ${
              step === "log"
                ? "bg-primary text-secondary"
                : "bg-gray-800 text-gray-300 hover:bg-gray-700"
            }`}
          >
            3. Log
          </button>
        </nav>
      </header>

      <main>
        {step === "input" && (
          <ContextInput
            context={context}
            setContext={setContext}
            setMetadata={setMetadata}
            setLoading={setLoading}
            loading={loading}
            onComplete={() => setStep("review")}
          />
        )}

        {step === "review" && metadata && (
          <ReviewEditor
            metadata={metadata}
            setMetadata={setMetadata}
            context={context}
          />
        )}

        {step === "log" && <PublishLog />}
      </main>
    </div>
  );
}
'@

# ---------- frontend/src/components/ContextInput.jsx ----------
$ctxInput = @'
import { useState } from "react";
import { api } from "../api/client";

export default function ContextInput({
  context, setContext, setMetadata, setLoading, loading, onComplete
}) {
  const [error, setError] = useState("");

  const handleGenerate = async () => {
    if (!context.trim()) {
      setError("Please enter video context");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const result = await api.generate(context);
      setMetadata(result);
      onComplete();
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto">
      <div className="bg-secondary rounded-lg p-6 border border-gray-800">
        <h2 className="text-xl font-semibold mb-2">Describe Your Video</h2>
        <p className="text-gray-400 text-sm mb-4">
          Topic, key points, target audience. The more detail, the better the metadata.
        </p>
        <textarea
          value={context}
          onChange={(e) => setContext(e.target.value)}
          placeholder="Example: A 10-minute tutorial on getting started with Rust for JavaScript developers. Cover ownership, borrowing, and build a small CLI tool. Target audience: intermediate JS devs who want to learn Rust."
          className="w-full h-48 p-3 bg-surface border border-gray-700 rounded text-white resize-none focus:border-primary focus:outline-none"
        />
        {error && <p className="text-accent mt-2 text-sm">{error}</p>}
        <button
          onClick={handleGenerate}
          disabled={loading}
          className="mt-4 w-full bg-primary text-secondary font-semibold py-3 rounded hover:opacity-90 disabled:opacity-50 transition"
        >
          {loading ? "Generating with Ollama..." : "Generate Metadata"}
        </button>
      </div>
    </div>
  );
}
'@

# ---------- frontend/src/components/ReviewEditor.jsx ----------
$reviewEditor = @'
import { useState } from "react";
import { api } from "../api/client";
import ThumbnailPreview from "./ThumbnailPreview";

export default function ReviewEditor({ metadata, setMetadata, context }) {
  const [regenerating, setRegenerating] = useState(null);
  const [videoPath, setVideoPath] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadResult, setUploadResult] = useState(null);

  const update = (field, value) => setMetadata({ ...metadata, [field]: value });

  const regen = async (field) => {
    setRegenerating(field);
    try {
      const result = await api.regenerate(field, context, metadata.selected_title);
      if (field === "title") {
        setMetadata({
          ...metadata,
          title_options: result.options,
          selected_title: result.options[0],
        });
      } else if (field === "thumbnail") {
        setMetadata({ ...metadata, thumbnail_prompts: result.prompts, thumbnail_raw: result.raw });
      } else {
        update(field, result[field]);
      }
    } catch (e) {
      alert("Regenerate failed: " + e.message);
    } finally {
      setRegenerating(null);
    }
  };

  const handleUpload = async () => {
    if (!videoPath.trim()) {
      alert("Please enter the path to your video file");
      return;
    }
    setUploading(true);
    setUploadResult(null);
    try {
      const finalMeta = {
        title: metadata.selected_title,
        description: metadata.description,
        tags: metadata.tags,
        category_id: metadata.category_id,
      };
      const result = await api.upload(videoPath, finalMeta);
      setUploadResult(result);
    } catch (e) {
      alert("Upload failed: " + e.message);
    } finally {
      setUploading(false);
    }
  };

  const regenBtn = (field) => (
    <button
      onClick={() => regen(field)}
      disabled={regenerating === field}
      className="text-xs bg-gray-700 hover:bg-gray-600 px-2 py-1 rounded disabled:opacity-50"
    >
      {regenerating === field ? "..." : "Regenerate"}
    </button>
  );

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 max-w-7xl mx-auto">
      <div className="space-y-4">
        <div className="bg-secondary p-4 rounded border border-gray-800">
          <div className="flex justify-between items-center mb-2">
            <label className="font-semibold text-primary">Title</label>
            {regenBtn("title")}
          </div>
          <select
            value={metadata.selected_title}
            onChange={(e) => update("selected_title", e.target.value)}
            className="w-full p-2 bg-surface border border-gray-700 rounded text-white"
          >
            {metadata.title_options?.map((t, i) => (
              <option key={i} value={t}>{t}</option>
            ))}
          </select>
        </div>

        <div className="bg-secondary p-4 rounded border border-gray-800">
          <div className="flex justify-between items-center mb-2">
            <label className="font-semibold text-primary">Description</label>
            {regenBtn("description")}
          </div>
          <textarea
            value={metadata.description}
            onChange={(e) => update("description", e.target.value)}
            className="w-full h-48 p-2 bg-surface border border-gray-700 rounded text-white text-sm resize-none"
          />
        </div>

        <div className="bg-secondary p-4 rounded border border-gray-800">
          <div className="flex justify-between items-center mb-2">
            <label className="font-semibold text-primary">
              Tags ({metadata.tags?.length || 0})
            </label>
            {regenBtn("tags")}
          </div>
          <textarea
            value={metadata.tags?.join(", ") || ""}
            onChange={(e) =>
              update("tags", e.target.value.split(",").map((t) => t.trim()).filter(Boolean))
            }
            className="w-full h-24 p-2 bg-surface border border-gray-700 rounded text-white text-sm"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-secondary p-4 rounded border border-gray-800">
            <div className="flex justify-between items-center mb-2">
              <label className="font-semibold text-primary text-sm">Hashtags</label>
              {regenBtn("hashtags")}
            </div>
            <input
              value={metadata.hashtags?.join(" ") || ""}
              onChange={(e) => update("hashtags", e.target.value.split(" ").filter(Boolean))}
              className="w-full p-2 bg-surface border border-gray-700 rounded text-white text-sm"
            />
          </div>
          <div className="bg-secondary p-4 rounded border border-gray-800">
            <label className="font-semibold text-primary text-sm">Category</label>
            <p className="mt-2 text-sm">
              {metadata.category_name} ({metadata.category_id})
            </p>
          </div>
        </div>
      </div>

      <div className="space-y-4">
        <ThumbnailPreview
          prompts={metadata.thumbnail_prompts}
          raw={metadata.thumbnail_raw}
          onRegenerate={() => regen("thumbnail")}
          regenerating={regenerating === "thumbnail"}
        />

        <div className="bg-secondary p-4 rounded border border-gray-800">
          <h3 className="font-semibold text-primary mb-3">Publish to YouTube</h3>
          <label className="text-sm text-gray-400">Video file path</label>
          <input
            value={videoPath}
            onChange={(e) => setVideoPath(e.target.value)}
            placeholder="D:\Videos\my-video.mp4"
            className="w-full p-2 mt-1 bg-surface border border-gray-700 rounded text-white text-sm"
          />
          <button
            onClick={handleUpload}
            disabled={uploading}
            className="mt-3 w-full bg-accent text-white font-semibold py-2.5 rounded hover:opacity-90 disabled:opacity-50 transition"
          >
            {uploading ? "Uploading..." : "Upload to YouTube"}
          </button>
          {uploadResult && (
            <div className="mt-3 p-3 bg-green-900/30 border border-green-700 rounded text-sm">
              Uploaded:{" "}
              <a href={uploadResult.url} target="_blank" rel="noreferrer" className="text-primary underline">
                {uploadResult.url}
              </a>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
'@

# ---------- frontend/src/components/ThumbnailPreview.jsx ----------
$thumbPreview = @'
export default function ThumbnailPreview({ prompts, raw, onRegenerate, regenerating }) {
  return (
    <div className="bg-secondary p-4 rounded border border-gray-800">
      <div className="flex justify-between items-center mb-3">
        <h3 className="font-semibold text-primary">Thumbnail Prompts (Nano Banana)</h3>
        <button
          onClick={onRegenerate}
          disabled={regenerating}
          className="text-xs bg-gray-700 hover:bg-gray-600 px-2 py-1 rounded disabled:opacity-50"
        >
          {regenerating ? "..." : "Regenerate"}
        </button>
      </div>
      <p className="text-xs text-gray-400 mb-3">
        Copy these prompts into Google AI Studio (Gemini 2.5 Flash Image / Nano Banana) to generate your thumbnail.
      </p>

      {prompts && prompts.length > 0 ? (
        <div className="space-y-3 max-h-96 overflow-y-auto">
          {prompts.map((p, i) => (
            <div key={i} className="p-3 bg-surface rounded border border-gray-700">
              <div className="text-xs text-primary font-bold mb-1">
                Concept {i + 1}: {p.text_overlay || "no text"}
              </div>
              <div className="text-xs text-gray-300 mb-2">
                <strong>Prompt:</strong> {p.prompt}
              </div>
              {p.composition && (
                <div className="text-xs text-gray-400">
                  <strong>Layout:</strong> {p.composition}
                </div>
              )}
              {p.mood && (
                <div className="text-xs text-gray-400">
                  <strong>Mood:</strong> {p.mood}
                </div>
              )}
              {p.colors && (
                <div className="text-xs text-gray-400">
                  <strong>Colors:</strong> {p.colors}
                </div>
              )}
              <button
                onClick={() => navigator.clipboard.writeText(p.prompt)}
                className="mt-2 text-xs bg-primary text-secondary px-2 py-1 rounded hover:opacity-90"
              >
                Copy prompt
              </button>
            </div>
          ))}
        </div>
      ) : (
        <pre className="text-xs text-gray-300 whitespace-pre-wrap bg-surface p-3 rounded max-h-96 overflow-y-auto">
          {raw}
        </pre>
      )}
    </div>
  );
}
'@

# ---------- frontend/src/components/PublishLog.jsx ----------
$publishLog = @'
import { useState, useEffect } from "react";
import { api } from "../api/client";

export default function PublishLog() {
  const [log, setLog] = useState([]);

  useEffect(() => {
    api.publishLog()
      .then((d) => setLog(d.log || []))
      .catch(console.error);
  }, []);

  return (
    <div className="max-w-4xl mx-auto">
      <h2 className="text-xl font-semibold mb-4">Publish Log</h2>
      {log.length === 0 ? (
        <p className="text-gray-400">No uploads yet. Publish your first video!</p>
      ) : (
        <div className="space-y-2">
          {log.slice().reverse().map((entry, i) => (
            <div key={i} className="bg-secondary p-3 rounded border border-gray-800">
              <div className="flex justify-between items-start">
                <span className="font-semibold">{entry.title}</span>
                <span className="text-xs text-gray-400">
                  {new Date(entry.timestamp).toLocaleString()}
                </span>
              </div>
              <a
                href={entry.url}
                target="_blank"
                rel="noreferrer"
                className="text-primary text-sm underline"
              >
                {entry.url}
              </a>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
'@

# ===========================================================================
# 8. DOCS
# ===========================================================================

# ---------- api-guide.md ----------
$apiGuide = @'
# YouTube Data API v3 Setup Guide

This walks you through the one-time OAuth setup lazy-tube needs to upload
videos on your behalf.

## 1. Create a Google Cloud project

1. Go to https://console.cloud.google.com
2. Create a new project (or select an existing one).
3. Open **APIs & Services -> Library**, search for **YouTube Data API v3**,
   and click **Enable**.

## 2. Configure the OAuth consent screen

1. Open **APIs & Services -> OAuth consent screen**.
2. Choose **External** (unless you have a Google Workspace org).
3. Fill in the required app fields (name, support email).
4. Under **Test users**, add the Google account(s) you will upload from.
   Skipping this step causes `access_denied` errors.

## 3. Create OAuth credentials

1. Open **APIs & Services -> Credentials -> Create Credentials -> OAuth client ID**.
2. Application type: **Desktop app** (NOT Web application - a Web app
   requires a manually configured redirect URI and will fail with
   `redirect_uri_mismatch`).
3. Download the resulting JSON file.
4. Save it as `data/client_secrets.json` in this project.

## 4. Required scopes

lazy-tube requests these scopes (already configured in `youtube_client.py`):

- `https://www.googleapis.com/auth/youtube.upload`
- `https://www.googleapis.com/auth/youtube.force-ssl`
- `https://www.googleapis.com/auth/youtube.readonly`

## 5. First run

The first upload opens a browser window for you to sign in and grant
access. A `youtube_token.pickle` file is then saved to `data/` so you
will not be prompted again until the token expires or is revoked.

## 6. Quota

The default YouTube API quota is 10,000 units/day. A single video
upload costs ~1,600 units, so you get roughly 6 uploads/day by default.
Request a higher quota under **APIs & Services -> Quotas** if you need more.
'@

# ---------- README.md ----------
$readme = @'
# lazy-tube

> AI-powered YouTube publishing assistant. Local-first. Brand-consistent. Dead simple.

lazy-tube takes a **text description** of your video and turns it into fully optimized YouTube metadata - **titles, descriptions, tags, hashtags, category, and Google Nano Banana thumbnail prompts** - using local LLMs via Ollama. Then it uploads straight to YouTube with one click.

No cloud LLM. No monthly fees. No vendor lock-in. Just your machine and your channel.

---

## Table of Contents
- [Why lazy-tube?](#why-lazy-tube)
- [Features](#features)
- [How It Works](#how-it-works)
- [Tech Stack](#tech-stack)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Project Structure](#project-structure)
- [Brand Profile Guide](#brand-profile-guide)
- [Managing Multiple Topics (Channel Bracket System)](#managing-multiple-topics-channel-bracket-system)
- [Thumbnail Workflow](#thumbnail-workflow)
- [YouTube Feature Reference](#youtube-feature-reference)
- [Daily Workflow](#daily-workflow)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)

---

## Why lazy-tube?

If you publish YouTube videos regularly, you have probably noticed:

1. **Writing metadata is tedious** - title variations, description structure, tag research, hashtags...
2. **Maintaining visual consistency is hard** - every thumbnail ends up looking slightly different
3. **Cloud AI tools charge per request** - and you give them your creative data
4. **YouTube Studio is slow** - multi-step uploads with no automation

lazy-tube solves all of this:

| Problem | lazy-tube Solution |
|---------|-------------------|
| Writing titles | 5 optimized options in 5 seconds |
| Description structure | Template-driven, brand-matched |
| Tag research | AI-generated, 20+ ranked tags |
| Hashtags | Channel tag + 3 video-specific |
| Thumbnail concept | 3 Nano Banana-ready prompts |
| Visual consistency | Brand profile + channel brackets |
| API costs | Free (local Ollama) |
| Data privacy | Everything runs locally |

---

## Features

### Core
- **Title Generation** - 5 variations, multiple styles (curiosity, how-to, listicle, news)
- **Description Generation** - Template-driven, brand-consistent
- **Tag Generation** - 20-25 ranked tags (broad + long-tail)
- **Hashtag Generation** - Channel tag + 3 video-specific
- **Category Classification** - Auto-maps to YouTube's 15 categories
- **Thumbnail Prompts** - 3 Nano Banana (Gemini 2.5 Flash Image) prompts per video

### Workflow
- **Human-in-the-loop review** - Edit any field, regenerate any field
- **Brand profile** - Single YAML file controls all outputs
- **Channel bracket system** - Manage multiple series in one channel
- **Reference thumbnails** - Pulls your recent uploads for style matching
- **Desktop OAuth** - Secure local token, no server-side auth
- **Publish log** - Track all uploads with timestamps and URLs

### Architecture
- **Local LLM** - llama3.1 (default), mistral (high quality), phi3 (fast drafts)
- **Async FastAPI backend** - Parallel skill execution
- **Electron + React UI** - Desktop app, no browser needed
- **Resumable uploads** - Handles 256GB files reliably
- **Restart-safe** - Tokens and logs persist across restarts

---

## How It Works

+-------------------------------------------------------------+ | 1. INPUT: You describe your video in plain text | | "10-min Rust tutorial for JS devs, covers ownership..." | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 2. AI PROCESSING (local Ollama, 6 parallel skills) | | |-- Title (5 options) | | |-- Description (template-driven) | | |-- Tags (20-25 ranked) | | |-- Hashtags (channel + video-specific) | | |-- Category (auto-classified) | | +-- Thumbnail (3 Nano Banana prompts) | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 3. REVIEW: You edit, regenerate, or accept | | . Side-by-side editor | | . Per-field regeneration | | . Thumbnail prompt preview | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 4. THUMBNAIL: You generate in Google AI Studio | | . Copy prompt -> Nano Banana -> Save image | | . (Optional) Add text overlay in Canva | +-----------------------------+-------------------------------+ v +-------------------------------------------------------------+ | 5. PUBLISH: One-click upload to YouTube | | . Resumable upload | | . Auto-set thumbnail | | . Logged to publish_log.json | +-------------------------------------------------------------+


---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Backend | FastAPI (Python 3.10+) | Async, fast, clean |
| LLM | Ollama (local) | Free, private, fast |
| Models | llama3.1, mistral, phi3 | Local, no API costs |
| Image prompts | Google Nano Banana (Gemini 2.5 Flash) | Best 16:9 thumbnails |
| YouTube API | google-api-python-client | Official, resumable |
| Frontend | Electron + React + Vite | Desktop feel, local-first |
| Styling | Tailwind CSS | Fast iteration |
| Storage | Local JSON + YAML | No database needed |

---

## Quick Start

### Prerequisites
- **Python 3.10+**
- **Node.js 18+**
- **Ollama** (install from https://ollama.com)
- **YouTube channel** + Google account

### One-time setup

```powershell
# 1. Pull Ollama models
ollama pull llama3.1
ollama pull mistral

# 2. Run the bootstrapper
cd D:\GitHub\lazy-tube
powershell -ExecutionPolicy Bypass -File setup.ps1

# 3. Install Python dependencies
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r ..\requirements.txt
cd ..

# 4. Install Node dependencies
cd frontend
npm install
cd ..

# 5. Set up YouTube API (see api-guide.md)
#    Save OAuth JSON as: data\client_secrets.json

# 6. Edit your brand profile
notepad data\brand_profile.yaml
Run
.\start.ps1
This opens:

Backend terminal: http://localhost:8000
Electron window: auto-opens when ready
First upload
Type your video context
Click "Generate Metadata"
Review/edit fields
Copy a thumbnail prompt -> generate in Google AI Studio -> save image
Enter video path + thumbnail path
Click "Upload to YouTube"
First time: browser opens for Google OAuth
Done - video is uploaded as private. Change to public in YouTube Studio when ready.
Detailed Setup
1. Ollama Setup
# Install from https://ollama.com
ollama pull llama3.1        # 4.7GB - default
ollama pull mistral         # 4.1GB - high quality
ollama pull phi3:mini       # 2.3GB - fast drafts (optional)
ollama list                 # verify
ollama serve                # if not auto-started
RAM requirements:

llama3.1 (8B): 8GB+ recommended
mistral (7B): 8GB+ recommended
Both together: 16GB+ recommended
2. YouTube API Setup
See api-guide.md for the complete walkthrough. Summary:

Create GCP project
Enable YouTube Data API v3
Configure OAuth consent screen
Create OAuth 2.0 Desktop app credentials (NOT Web app)
Download JSON -> save as data/client_secrets.json
Critical: Use "Desktop app" type. lazy-tube uses a local OAuth flow.

3. Brand Profile
Edit data/brand_profile.yaml. This is the most important file - it controls all outputs.

4. Channel Brackets (Optional but Recommended)
If your channel has multiple series, configure the bracket system.

Project Structure
lazy-tube/
+- backend/                        # FastAPI + Ollama skills
|  +- main.py                    # App entry point
|  +- api/
|  |  +- generate.py            # POST /generate
|  +- skills/                    # One file per metadata field
|  +- core/                      # Infrastructure
+- frontend/                       # Electron + React + Vite
|  +- main.js                    # Electron main process
|  +- src/
|     +- App.jsx
|     +- components/
+- config/                         # Runtime config
+- data/                           # User data (gitignored)
|  +- brand_profile.yaml         # <-- EDIT THIS
|  +- client_secrets.json        # <-- YouTube OAuth
+- logs/                           # Auto-generated logs
+- api-guide.md                    # YouTube API setup
+- README.md                       # This file
+- setup.ps1                       # Project bootstrapper
+- start.ps1                       # Launch script
+- requirements.txt
Brand Profile Guide
The brand profile (data/brand_profile.yaml) is your single source of truth for channel identity.

Channel identity
channel:
  name: "TechSimplified"
  tone: "informative, friendly, slightly humorous"
  audience: "developers, tech enthusiasts"
  about: "We make complex tech topics simple."
Visual brand
visual_brand:
  primary_color: "#00D4FF"
  secondary_color: "#1A1A2E"
  accent_color: "#FF006E"
  mood: "modern, clean, futuristic"
Title style
title_style:
  pattern: "{topic}: {hook}"
  examples:
    - "Rust is Eating JavaScript: Heres Why"
    - "5 Python Tricks I Wish I Knew Earlier"
Description template
description_template: |
  {hook}

  In this video:
  {bullets}

  Timestamps:
  0:00 Intro
  {chapters}

  Links:
  {links}
  {hashtags}
Hashtags
hashtags_fixed:
  - "YourChannelTag"      # Always included
Pro tips
More examples = better AI output. Add 5-10 real title examples.
Be specific about tone. "sarcastic and edgy" is different from "playful and educational".
Update visual colors when you rebrand. The AI adapts thumbnails.
Keep the description template simple. The AI fills the variables.
Managing Multiple Topics (Channel Bracket System)
The problem
You want ONE channel but MULTIPLE series. Each series may need different:

Playlists
Visual mood
Sometimes even colors
The solution: Channel brackets
Configure in brand_profile.yaml:

channel_bracket_system:
  - topic: "AI & Machine Learning"
    playlist_name: "AI Weekly"
    visual_mood: "futuristic, neon, dark backgrounds"
  - topic: "Python Development"
    playlist_name: "Python Tips"
    visual_mood: "clean, code-on-screen, light backgrounds"
  - topic: "Tool Reviews"
    playlist_name: "Tool Showdown"
    visual_mood: "product shots, side-by-side comparisons"
When you generate metadata, the AI:

Reads your context
Matches it to the most relevant bracket
Applies that bracket's visual mood to thumbnail prompts
Tags the description with the right playlist name
The 3 pillars of uniformity
1. Visual (thumbnails)

Same color palette (or accept the bracket override)
Same font, same logo position
Same composition (e.g., "subject right, text left")
2. Verbal (titles & descriptions)

Same fixed hashtag in every video
Same intro sentence in every description
Same title structure pattern
3. Structural (video itself)

Same intro length (5-10 sec)
Same outro
Same chapter style
These go in your brand_profile.yaml and apply across all brackets.

Thumbnail Workflow
Step 1: AI generates prompts
In the review screen, you will see 3 Nano Banana prompts like:

Concept 1: GPT-5 IS HERE
Prompt: Cinematic shot of a glowing neural network...
TextOverlay: GPT-5 IS HERE
Mood: futuristic, exciting
Colors: #00D4FF, #1A1A2E, #FF006E
Step 2: Generate in Google AI Studio
Go to https://aistudio.google.com
Select "Gemini 2.5 Flash Image" (Nano Banana)
Paste the prompt
Click "Generate"
Download the image
Step 3: Add text overlay (optional)
Canva (free): Use your brand fonts
Photoshop: Pro control
Figma: Quick and clean
Match the TextOverlay and Colors from the AI prompt.

Step 4: Upload
In lazy-tube, paste the image path. The app auto-uploads it to YouTube with your video.

Tips
Always test multiple concepts. YouTube has a free A/B test tool.
Match the thumbnail to the title. Do not oversell.
Use high contrast. Mobile thumbnails are tiny.
Avoid more than 5 words on the thumbnail.
YouTube Feature Reference
When to use each feature
Feature	When to Use	Why It Matters
Playlists	Group videos by topic/series	SEO + viewer binge-watch
Tags	Always fill all 30 slots	Search discoverability
Chapters	Videos > 2 min	SEO + viewer experience
End screens	Last 20 sec of video	Promote next video
Cards	Mid-video topic mentions	Cross-link old content
Pinned comment	Every upload	Engagement boost
Community tab	1-2x/week	Channel activity signal
Shorts	Repurpose long video highlights	10x reach
Premieres	Major launches only	Hype + live chat replay
Thumbnails A/B	Always test	YouTube's free tool
Analytics checklist (weekly)
Audience tab - what topics do viewers actually want?
Traffic sources - where are views coming from?
Top videos - what is working? Make more like it.
CTR + AVD - if CTR < 4%, test new thumbnails.
Comments - answer every comment in first hour.
Daily Workflow
Publishing a new video
Edit & export your video (e.g., D:\Videos\my-video.mp4)
Open lazy-tube (.\start.ps1)
Type context: "10-min Rust tutorial for JS devs..."
Generate metadata (5-10 sec)
Review titles, edit description, check tags
Copy thumbnail prompt -> Google AI Studio -> save image
(Optional) Add text overlay in Canva
Enter paths in upload section
Click Upload - browser opens for OAuth (first time only)
Set visibility in YouTube Studio (private -> public)
Post community tab announcement
Check publish_log.json to confirm
Troubleshooting
Ollama issues
"Connection refused" to localhost:11434

ollama serve
"Model not found"

ollama pull llama3.1
ollama list
Slow generation

Use phi3:mini for drafts (2.3GB)
Reduce temperature in prompts
Close other heavy apps
YouTube API issues
"redirect_uri_mismatch"

Make sure you selected Desktop app type, NOT Web app
Desktop flow does not need manual redirect URI
"access_denied"

Add your email as a test user in OAuth consent screen
Make sure you granted all 3 scopes
"quotaExceeded"

YouTube default: 10,000 units/day
1 upload = 1,600 units -> max 6 uploads/day
Request increase: Cloud Console -> APIs & Services -> YouTube Data API v3 -> Quotas
"Video not found" after upload

Check logs/publish_log.json for the video ID
Visit https://youtu.be/{video_id} directly
Frontend issues
Electron window does not open

Check the backend terminal for errors
Open http://localhost:5173 in browser manually to debug
CORS errors

Backend runs on port 8000, frontend on 5173
Check frontend/vite.config.js proxy settings
Tailwind styles not applying

cd frontend
npm install
npm run dev
General
AI output is low quality

Add more examples to brand_profile.yaml
Be more specific in your context
Try a different model (mistral for quality, phi3 for speed)
Thumbnail prompt is generic

Add 5-10 reference thumbnails from your channel
Be more specific in your video context
Add custom style notes to brand_profile.yaml
Roadmap
v0.2 (next)
 Whisper transcription for video input mode
 Auto-fetch chapter timestamps from video
 Bulk video processing
 Schedule publish (date/time)
 Multi-channel support
v0.3
 YouTube Analytics integration
 A/B test thumbnail picker
 Auto-publish to TikTok/Instagram Reels
 Local Stable Diffusion for thumbnails (no Nano Banana)
 Video SEO scoring (out of 100)
v1.0
 Cloud sync (optional, encrypted)
 Team collaboration
 Plugin system
 Web version (in addition to desktop)
Contributing
This is a personal tool, but if you fork it and improve it, I would love to hear about it. Open an issue with:

What you changed
Why it is better
Screenshots if UI-related
License
MIT - do whatever you want. Just do not blame me if your YouTube channel goes viral. ;)

Credits
Built with:

Ollama - local LLMs
FastAPI - backend
React + Electron - frontend
Tailwind CSS - styling
Google Nano Banana - thumbnail generation
YouTube Data API v3 - publishing
Happy publishing!
'@

# ===========================================================================
# 9. WRITE ALL FILES TO DISK
# ===========================================================================
Write-Host "`n=== Writing project files ===" -ForegroundColor Cyan

$files = @{
    "backend\__init__.py" = $backendInit
    "backend\api\__init__.py" = $apiInit
    "backend\skills\__init__.py" = $skillsInit
    "backend\core\__init__.py" = $coreInit
    "api-guide.md" = $apiGuide
    "backend\main.py" = $mainPy
    "backend\core\ollama_client.py" = $ollamaPy
    "backend\core\brand_loader.py" = $brandPy
    "backend\core\config_compiler.py" = $compilerPy
    "backend\core\youtube_client.py" = $ytPy
    "backend\skills\title_skill.py" = $titlePy
    "backend\skills\description_skill.py" = $descPy
    "backend\skills\tag_skill.py" = $tagPy
    "backend\skills\category_skill.py" = $catPy
    "backend\skills\hashtag_skill.py" = $hashPy
    "backend\skills\thumbnail_prompt_skill.py" = $thumbPy
    "backend\api\generate.py" = $genApiPy
    "backend\api\review.py" = $reviewPy
    "backend\api\upload.py" = $uploadPy
    "backend\api\youtube_helpers.py" = $ytHelperPy
    "config\youtube_config.yaml" = $ytYaml
    "config\ollama_config.yaml" = $ollamaYaml
    "data\brand_profile.yaml" = $brandYaml
    "requirements.txt" = $reqTxt
    ".gitignore" = $gitignore
    "start.ps1" = $startPs1
    "frontend\package.json" = $pkgJson
    "frontend\vite.config.js" = $viteConfig
    "frontend\tailwind.config.js" = $twConfig
    "frontend\postcss.config.js" = $postcssConfig
    "frontend\index.html" = $indexHtml
    "frontend\main.js" = $electronMain
    "frontend\preload.js" = $preloadJs
    "frontend\.gitignore" = $feGitignore
    "frontend\src\main.jsx" = $feMain
    "frontend\src\index.css" = $feCss
    "frontend\src\api\client.js" = $apiClient
    "frontend\src\App.jsx" = $appJsx
    "frontend\src\components\ContextInput.jsx" = $ctxInput
    "frontend\src\components\ReviewEditor.jsx" = $reviewEditor
    "frontend\src\components\ThumbnailPreview.jsx" = $thumbPreview
    "frontend\src\components\PublishLog.jsx" = $publishLog
    "README.md" = $readme
}

$writeErrors = 0
foreach ($entry in $files.GetEnumerator() | Sort-Object Name) {
    $ok = Write-File $entry.Key $entry.Value
    if (-not $ok) { $writeErrors++ }
}

Write-Host ""
if ($writeErrors -gt 0) {
    Write-Host "[ERROR] $writeErrors file(s) failed to write. See above." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] $($files.Count) files written successfully" -ForegroundColor Green

# ===========================================================================
# 10. VERIFY README.md (detailed check)
# ===========================================================================
$readmePath = Join-Path $root "README.md"
if (Test-Path $readmePath) {
    $size = (Get-Item $readmePath).Length
    $lines = ([System.IO.File]::ReadAllLines($readmePath)).Count
    Write-Host "`n=== README.md verification ===" -ForegroundColor Cyan
    Write-Host "[OK] README.md created successfully" -ForegroundColor Green
    Write-Host "     Path:  $readmePath" -ForegroundColor Gray
    Write-Host "     Size:  $size bytes" -ForegroundColor Gray
    Write-Host "     Lines: $lines" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Preview (first 5 lines):" -ForegroundColor Cyan
    Get-Content $readmePath -TotalCount 5 | ForEach-Object {
        Write-Host "     $_" -ForegroundColor White
    }
    Write-Host ""
}
else {
    Write-Host "[ERROR] Failed to create README.md" -ForegroundColor Red
    exit 1
}

# ===========================================================================
# 11. DONE
# ===========================================================================
Write-Host "=== lazy-tube bootstrap complete ===" -ForegroundColor Cyan
Write-Host "Project created at: $root" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd `"$root`"" -ForegroundColor White
Write-Host "  2. Edit data\brand_profile.yaml with your channel identity" -ForegroundColor White
Write-Host "  3. Follow api-guide.md to set up YouTube OAuth credentials" -ForegroundColor White
Write-Host "  4. Run: python -m venv .venv; .venv\Scripts\Activate.ps1; pip install -r requirements.txt" -ForegroundColor White
Write-Host "  5. Run: .\start.ps1" -ForegroundColor White
Write-Host ""
