import yaml
import os

from core.config_manager import get_config_path, get_data_path


def load_brand(path: str = None) -> dict:
    candidates = []
    if path:
        candidates.append(path)
    candidates.extend([
        get_data_path("brand_profile.yaml"),
        get_config_path("brand_profile.yaml"),
    ])

    for candidate in candidates:
        if os.path.exists(candidate):
            with open(candidate, "r", encoding="utf-8") as f:
                return yaml.safe_load(f)

    raise FileNotFoundError("brand_profile.yaml not found in packaged data/config folders")


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