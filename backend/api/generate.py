from typing import Optional

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
    brand_path: Optional[str] = None
    include_thumbnail: bool = True


def _load_pipeline_deps(brand_path: Optional[str]):
    """Load brand config + Ollama client, raising a clear HTTPException
    (instead of a bare 500) if either is missing or malformed."""
    try:
        brand = load_brand(brand_path)
    except FileNotFoundError as e:
        raise HTTPException(
            500,
            f"Brand profile not found: {e}. "
            f"Make sure data/brand_profile.yaml exists.",
        )
    except Exception as e:
        raise HTTPException(500, f"Failed to load brand profile: {e}")

    try:
        ollama = OllamaClient()
    except FileNotFoundError as e:
        raise HTTPException(
            500,
            f"Ollama config not found: {e}. "
            f"Make sure config/ollama_config.yaml exists.",
        )
    except Exception as e:
        raise HTTPException(500, f"Failed to load Ollama config: {e}")

    return brand, ollama


@router.post("/generate")
async def generate_metadata(req: GenerateRequest):
    if not req.context.strip():
        raise HTTPException(400, "Context cannot be empty")

    brand, ollama = _load_pipeline_deps(req.brand_path)

    ref_thumbs = []
    if req.include_thumbnail:
        try:
            yt = YouTubeClient()
            ref_thumbs = yt.list_recent_thumbnails(max_results=3)
        except Exception as e:
            print(f"Could not fetch reference thumbnails: {e}")

    try:
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
    except Exception as e:
        raise HTTPException(500, f"Generation pipeline failed: {e}")

    return {
        "title_options": title_result.get("titles", []),
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
    selected_title: Optional[str] = None
    brand_path: Optional[str] = None


@router.post("/regenerate")
async def regenerate_field(req: RegenerateRequest):
    if not req.context.strip():
        raise HTTPException(400, "Context cannot be empty")

    brand, ollama = _load_pipeline_deps(req.brand_path)
    title = req.selected_title or ""

    try:
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
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"Regeneration failed: {e}")