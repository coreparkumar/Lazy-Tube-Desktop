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