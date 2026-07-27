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