

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
import os
import json
import logging
import traceback
from datetime import datetime
from typing import Optional, Any, Dict, Union

from core.youtube_client import YouTubeClient
from core.config_compiler import compile_youtube_payload
from core.brand_loader import load_brand

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

router = APIRouter()
LOG_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "logs", "publish_log.json")


# ============================================================
#  Flexible upload request schema
#  Accepts snake_case, camelCase, and missing fields gracefully
# ============================================================
class UploadRequest(BaseModel):
    # Video path - accepts 3 different field names
    video_path: Optional[str] = None
    videoPath: Optional[str] = None
    file_path: Optional[str] = None

    # Thumbnail path - accepts 2 different field names
    thumbnail_path: Optional[str] = Field(default=None, nullable=True)
    thumbnailPath: Optional[str] = Field(default=None, nullable=True)

    # Metadata - flexible, can be dict or object
    metadata: Optional[Union[Dict[str, Any], Any]] = None

    # Scheduled publish (ISO 8601 string)
    scheduled_publish: Optional[str] = None

    class Config:
        # Ignore unknown fields (forward compatibility)
        extra = "ignore"

    # ------------------------------------------------------------
    #  Helper methods to normalize input
    # ------------------------------------------------------------
    def get_video_path(self) -> str:
        """Get video path from any accepted field name. Raises if missing."""
        path = self.video_path or self.videoPath or self.file_path
        if not path or not str(path).strip():
            raise ValueError(
                "video_path is required "
                "(use field 'video_path', 'videoPath', or 'file_path')"
            )
        return str(path).strip()

    def get_thumbnail_path(self) -> Optional[str]:
        """Get thumbnail path from any accepted field name."""
        return self.thumbnail_path or self.thumbnailPath

    def get_metadata(self) -> Dict[str, Any]:
        """
        Normalize metadata into the exact format the YouTube compiler expects.
        Handles missing fields, wrong types, alternate field names.
        """
        # ---- Default metadata if missing ----
        if self.metadata is None:
            logger.warning("No metadata provided, using defaults")
            return {
                "title": "Untitled Video",
                "description": "",
                "tags": [],
                "category_id": 22,
            }

        # ---- Convert to dict ----
        if isinstance(self.metadata, dict):
            meta = self.metadata
        elif hasattr(self.metadata, "__dict__"):
            meta = vars(self.metadata)
        elif isinstance(self.metadata, str):
            # Maybe JSON string?
            try:
                meta = json.loads(self.metadata)
            except Exception:
                logger.warning("Metadata is a string but not valid JSON, ignoring")
                meta = {}
        else:
            meta = dict(self.metadata) if hasattr(self.metadata, "keys") else {}

        # ---- Extract title (multiple field name fallbacks) ----
        title = (
            meta.get("title")
            or meta.get("selected_title")
            or meta.get("selectedTitle")
            or meta.get("video_title")
            or "Untitled Video"
        )
        title = str(title).strip()[:100]  # YouTube max is 100 chars
        if not title:
            title = "Untitled Video"

        # ---- Extract description ----
        description = (
            meta.get("description")
            or meta.get("desc")
            or meta.get("summary")
            or ""
        )
        description = str(description)[:5000]  # YouTube max is 5000

        # ---- Extract tags (normalize to list of strings) ----
        tags_raw = (
            meta.get("tags")
            or meta.get("tag_list")
            or meta.get("tagList")
            or []
        )
        if isinstance(tags_raw, str):
            tags = [t.strip() for t in tags_raw.replace(";", ",").split(",") if t.strip()]
        elif isinstance(tags_raw, (list, tuple)):
            tags = [str(t).strip() for t in tags_raw if t]
        else:
            tags = []
        tags = tags[:30]  # YouTube max is ~500 chars total, 30 is safe

        # ---- Extract category_id (multiple field name fallbacks) ----
        category_id = (
            meta.get("category_id")
            or meta.get("categoryId")
            or meta.get("category")
            or 22
        )
        try:
            category_id = int(category_id)
        except (TypeError, ValueError):
            category_id = 22
        # YouTube category IDs are 1-29
        if category_id < 1 or category_id > 29:
            category_id = 22

        # ---- Extract optional fields ----
        default_language = meta.get("default_language") or meta.get("defaultLanguage")
        privacy_status = meta.get("privacy_status") or meta.get("privacyStatus")

        return {
            "title": title,
            "description": description,
            "tags": tags,
            "category_id": category_id,
            "default_language": default_language,
            "privacy_status": privacy_status,
        }


# ============================================================
#  Upload endpoint
# ============================================================
@router.post("/upload")
async def upload_video(req: UploadRequest):
    # ---- Step 1: Validate and normalize inputs ----
    try:
        video_path = req.get_video_path()
    except ValueError as e:
        raise HTTPException(400, str(e))

    thumbnail_path = req.get_thumbnail_path()
    metadata = req.get_metadata()

    logger.info(
        f"Upload request: video='{video_path}', "
        f"title='{metadata['title'][:50]}', "
        f"thumbnail={'yes' if thumbnail_path else 'no'}, "
        f"scheduled={'yes' if req.scheduled_publish else 'no'}"
    )

    # ---- Step 2: Check video file exists ----
    if not os.path.exists(video_path):
        raise HTTPException(
            status_code=404,
            detail=f"Video file not found: {video_path}"
        )

    # ---- Step 3: Check video file is readable ----
    if not os.path.isfile(video_path):
        raise HTTPException(
            status_code=400,
            detail=f"Path is not a file: {video_path}"
        )

    # ---- Step 4: Check thumbnail (if provided) ----
    if thumbnail_path and not os.path.exists(thumbnail_path):
        logger.warning(f"Thumbnail not found: {thumbnail_path}, continuing without it")
        thumbnail_path = None

    # ---- Step 5: Load brand defaults ----
    try:
        brand = load_brand()
    except Exception as e:
        logger.error(f"Failed to load brand: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(500, f"Brand profile error: {e}")

    # ---- Step 6: Build YouTube upload defaults ----
    yt_defaults_from_brand = brand.get("youtube_defaults", {})
    defaults = {
        "visibility": (
            metadata.get("privacy_status")
            or yt_defaults_from_brand.get("visibility", "private")
        ),
        "made_for_kids": yt_defaults_from_brand.get("made_for_kids", False),
        "embeddable": yt_defaults_from_brand.get("embeddable", True),
        "license": yt_defaults_from_brand.get("license", "youtube"),
    }

    # ---- Step 7: Compile YouTube API payload ----
    try:
        payload = compile_youtube_payload(metadata, defaults, req.scheduled_publish)
        logger.info(f"Compiled payload: title='{payload['snippet']['title'][:50]}'")
    except Exception as e:
        logger.error(f"Failed to compile payload: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(500, f"Failed to compile upload payload: {e}")

    # ---- Step 8: Authenticate and upload ----
    try:
        yt = YouTubeClient()
        yt.authenticate()
        result = yt.upload_video(video_path, payload, thumbnail_path)
    except FileNotFoundError as e:
        logger.error(f"OAuth credentials missing: {e}")
        raise HTTPException(
            status_code=401,
            detail=(
                "YouTube OAuth credentials not found. "
                "See api-guide.md for setup. "
                f"({e})"
            )
        )
    except Exception as e:
        logger.error(f"Upload failed: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(500, f"Upload failed: {e}")

    # ---- Step 9: Log the publish ----
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
        log = []
        if os.path.exists(LOG_PATH):
            try:
                with open(LOG_PATH, "r", encoding="utf-8") as f:
                    log = json.load(f)
                if not isinstance(log, list):
                    log = []
            except Exception:
                log = []

        log.append({
            "timestamp": datetime.now().isoformat(),
            "video_id": result.get("video_id"),
            "url": result.get("url"),
            "title": metadata["title"],
            "thumbnail_set": result.get("thumbnail_set", False),
        })

        with open(LOG_PATH, "w", encoding="utf-8") as f:
            json.dump(log, f, indent=2)
        logger.info(f"Publish logged: {result.get('url')}")
    except Exception as e:
        logger.warning(f"Failed to write publish log: {e}")

    # ---- Step 10: Return success ----
    return {
        "success": True,
        "video_id": result.get("video_id"),
        "url": result.get("url"),
        "thumbnail_set": result.get("thumbnail_set", False),
        "thumbnail_error": result.get("thumbnail_error"),
    }


# ============================================================
#  Publish log endpoint
# ============================================================
@router.get("/upload/log")
async def get_publish_log():
    if not os.path.exists(LOG_PATH):
        return {"log": [], "count": 0}
    try:
        with open(LOG_PATH, "r", encoding="utf-8") as f:
            log = json.load(f)
        if not isinstance(log, list):
            return {"log": [], "count": 0, "error": "Log file is corrupted"}
        return {"log": log, "count": len(log)}
    except json.JSONDecodeError as e:
        return {"log": [], "count": 0, "error": f"Invalid JSON in log: {e}"}
    except Exception as e:
        return {"log": [], "count": 0, "error": str(e)}


# ============================================================
#  Clear log endpoint (for testing)
# ============================================================
@router.delete("/upload/log")
async def clear_publish_log():
    try:
        if os.path.exists(LOG_PATH):
            os.remove(LOG_PATH)
        return {"cleared": True}
    except Exception as e:
        raise HTTPException(500, f"Failed to clear log: {e}")
