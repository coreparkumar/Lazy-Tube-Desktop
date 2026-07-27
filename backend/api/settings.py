import os
import pickle
import yaml
from fastapi import APIRouter, HTTPException, UploadFile, File  # type: ignore[import-not-found]
from pydantic import BaseModel
from google_auth_oauthlib.flow import InstalledAppFlow
from core.config_manager import get_config_path, get_data_path

router = APIRouter(prefix="/settings", tags=["Settings"])

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.readonly"
]

BRAND_YAML_PATH = get_config_path("brand_profile.yaml")
CLIENT_SECRETS_FILE = get_data_path("client_secrets.json")
TOKEN_PICKLE_FILE = get_data_path("youtube_token.pickle")

class BrandProfileModel(BaseModel):
    yaml_content: str

@router.get("/brand-profile")
def get_brand_profile():
    if not os.path.exists(BRAND_YAML_PATH):
        return {"yaml_content": ""}
    with open(BRAND_YAML_PATH, "r", encoding="utf-8") as f:
        return {"yaml_content": f.read()}

@router.post("/brand-profile")
def update_brand_profile(data: BrandProfileModel):
    try:
        yaml.safe_load(data.yaml_content)
        with open(BRAND_YAML_PATH, "w", encoding="utf-8") as f:
            f.write(data.yaml_content)
        return {"status": "success", "message": "Brand profile saved successfully!"}
    except yaml.YAMLError as e:
        raise HTTPException(status_code=400, detail=f"Invalid YAML syntax: {str(e)}")

@router.post("/upload-client-secrets")
async def upload_client_secrets(file: UploadFile = File(...)):
    content = await file.read()
    with open(CLIENT_SECRETS_FILE, "wb") as f:
        f.write(content)
    if os.path.exists(TOKEN_PICKLE_FILE):
        os.remove(TOKEN_PICKLE_FILE)
    return {"status": "success", "message": "Client secrets saved. Please connect channel now."}

@router.post("/connect-youtube")
def connect_youtube():
    if not os.path.exists(CLIENT_SECRETS_FILE):
        raise HTTPException(status_code=400, detail="Missing client_secrets.json. Please upload it first.")

    flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRETS_FILE, SCOPES)
    credentials = flow.run_local_server(port=8080, prompt="consent")

    with open(TOKEN_PICKLE_FILE, "wb") as token_file:
        pickle.dump(credentials, token_file)

    return {"status": "success", "message": "YouTube channel authorized successfully!"}

@router.get("/channel-status")
def channel_status():
    return {
        "secrets_uploaded": os.path.exists(CLIENT_SECRETS_FILE),
        "channel_connected": os.path.exists(TOKEN_PICKLE_FILE)
    }
