import os
import pickle
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
import yaml

from core.config_manager import get_config_path, get_data_path

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly",
]


class YouTubeClient:
    def __init__(self, config_path: str = None):
        if config_path is None:
            config_path = get_config_path("youtube_config.yaml")
        with open(config_path, "r", encoding="utf-8") as f:
            self.config = yaml.safe_load(f)["youtube"]
        self.creds = None
        self.service = None

    def _token_path(self) -> str:
        return get_data_path("youtube_token.pickle")

    def _secrets_path(self) -> str:
        cfg = self.config.get("client_secrets_file", "data/client_secrets.json")
        candidate = os.path.normpath(cfg)
        if os.path.isabs(candidate):
            return candidate

        resolved_name = os.path.basename(candidate)
        for base_dir in (get_data_path(""), get_config_path("")):
            potential = os.path.join(base_dir, resolved_name)
            if os.path.exists(potential):
                return potential

        return get_data_path(resolved_name)

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