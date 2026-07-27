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