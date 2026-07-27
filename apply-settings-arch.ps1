<#
.SYNOPSIS
    Applies persistent user configuration and OAuth channel management architecture to Lazy-Tube.
#>

$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Applying Lazy-Tube Dynamic Configuration System" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create Folder System
Write-Host "[1/5] Setting up config and data directories..." -ForegroundColor Yellow
$ConfigDir = Join-Path $ProjectRoot "config"
$DataDir   = Join-Path $ProjectRoot "data"
$BackendCoreDir = Join-Path $ProjectRoot "backend\core"
$BackendApiDir  = Join-Path $ProjectRoot "backend\api"
$FrontendSrcDir = Join-Path $ProjectRoot "frontend\src\components"

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $BackendCoreDir | Out-Null
New-Item -ItemType Directory -Force -Path $BackendApiDir | Out-Null
New-Item -ItemType Directory -Force -Path $FrontendSrcDir | Out-Null

# 2. Create core/config_manager.py
Write-Host "[2/5] Creating backend/core/config_manager.py..." -ForegroundColor Yellow
$ConfigManagerPy = @"
import os
import sys

def get_base_dir() -> str:
    """Returns directory containing the EXE or project root."""
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def get_config_path(filename: str) -> str:
    config_dir = os.path.join(get_base_dir(), "config")
    os.makedirs(config_dir, exist_ok=True)
    return os.path.join(config_dir, filename)

def get_data_path(filename: str) -> str:
    data_dir = os.path.join(get_base_dir(), "data")
    os.makedirs(data_dir, exist_ok=True)
    return os.path.join(data_dir, filename)
"@
Set-Content -Path (Join-Path $BackendCoreDir "config_manager.py") -Value $ConfigManagerPy -Encoding UTF8

# 3. Create backend/api/settings.py
Write-Host "[3/5] Creating backend/api/settings.py for OAuth and Brand Profile..." -ForegroundColor Yellow
$SettingsPy = @"
import os
import pickle
import yaml
from fastapi import APIRouter, HTTPException, UploadFile, File
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
CLIENT_SECRETS_FILE = get_config_path("client_secrets.json")
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
"@
Set-Content -Path (Join-Path $BackendApiDir "settings.py") -Value $SettingsPy -Encoding UTF8

# 4. Create Settings Tab React Component
Write-Host "[4/5] Creating frontend/src/components/SettingsTab.jsx..." -ForegroundColor Yellow
$SettingsJsx = @"
import React, { useState, useEffect } from 'react';

export function SettingsTab() {
  const [yamlContent, setYamlContent] = useState('');
  const [statusMsg, setStatusMsg] = useState('');
  const [channelStatus, setChannelStatus] = useState({ secrets_uploaded: false, channel_connected: false });

  const fetchChannelStatus = async () => {
    try {
      const res = await fetch('/api/settings/channel-status');
      const data = await res.json();
      setChannelStatus(data);
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    fetch('/api/settings/brand-profile')
      .then(res => res.json())
      .then(data => setYamlContent(data.yaml_content || ''));
    fetchChannelStatus();
  }, []);

  const handleSaveYaml = async () => {
    setStatusMsg('Saving YAML...');
    const res = await fetch('/api/settings/brand-profile', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ yaml_content: yamlContent })
    });
    const data = await res.json();
    setStatusMsg(data.message || data.detail);
  };

  const handleFileUpload = async (e) => {
    if (!e.target.files[0]) return;
    const formData = new FormData();
    formData.append('file', e.target.files[0]);
    setStatusMsg('Uploading client secrets...');
    const res = await fetch('/api/settings/upload-client-secrets', { method: 'POST', body: formData });
    const data = await res.json();
    setStatusMsg(data.message);
    fetchChannelStatus();
  };

  const handleConnectChannel = async () => {
    setStatusMsg('Opening Google OAuth in browser...');
    const res = await fetch('/api/settings/connect-youtube', { method: 'POST' });
    const data = await res.json();
    setStatusMsg(data.message || data.detail);
    fetchChannelStatus();
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif', color: '#eaeaea', backgroundColor: '#121212', minHeight: '100vh' }}>
      <h2>Lazy-Tube Channel & Brand Settings</h2>

      <div style={{ marginBottom: '20px', border: '1px solid #333', padding: '15px', borderRadius: '6px' }}>
        <h3>1. YouTube Channel Authorization</h3>
        <p>Status: 
          <strong> {channelStatus.channel_connected ? ' Connected' : ' Not Connected'}</strong> | 
          Credentials: <strong>{channelStatus.secrets_uploaded ? ' Uploaded' : ' Missing'}</strong>
        </p>

        <div style={{ marginBottom: '10px' }}>
          <label style={{ display: 'block', marginBottom: '5px' }}>Upload <code>client_secrets.json</code>:</label>
          <input type="file" accept=".json" onChange={handleFileUpload} />
        </div>

        <button 
          onClick={handleConnectChannel} 
          disabled={!channelStatus.secrets_uploaded}
          style={{ padding: '8px 16px', cursor: channelStatus.secrets_uploaded ? 'pointer' : 'not-allowed' }}
        >
          Authenticate / Switch YouTube Channel
        </button>
      </div>

      <div style={{ border: '1px solid #333', padding: '15px', borderRadius: '6px' }}>
        <h3>2. Edit Brand Profile & Metadata Prompt Rules</h3>
        <textarea 
          rows={18} 
          style={{ width: '100%', fontFamily: 'monospace', backgroundColor: '#1e1e1e', color: '#00d4ff', padding: '10px' }}
          value={yamlContent} 
          onChange={(e) => setYamlContent(e.target.value)} 
        />
        <button onClick={handleSaveYaml} style={{ marginTop: '10px', padding: '8px 16px', cursor: 'pointer' }}>
          Save Brand Profile
        </button>
      </div>

      {statusMsg && (
        <div style={{ marginTop: '15px', padding: '10px', background: '#222', borderLeft: '4px solid #00d4ff' }}>
          <strong>Status:</strong> {statusMsg}
        </div>
      )}
    </div>
  );
}
"@
Set-Content -Path (Join-Path $FrontendSrcDir "SettingsTab.jsx") -Value $SettingsJsx -Encoding UTF8

# 5. Update publish.bat
Write-Host "[5/5] Updating publish.bat to copy persistent directories..." -ForegroundColor Yellow
$PublishBat = @"
@echo off
SETLOCAL EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

set PYTHON_EXE=%~dp0backend\.venv\Scripts\python.exe
if not exist "%PYTHON_EXE%" (
    echo [ERROR] Backend virtual environment not found.
    echo         Run build.bat first to create the backend environment.
    exit /b 1
)

set ICON_ICO=%~dp0frontend\src\components\lazy-tube-ico.ico
if not exist "%ICON_ICO%" (
    echo [ERROR] Icon file not found: %ICON_ICO%
    exit /b 1
)

echo.
echo ============================================================
echo   Lazy-Tube Release Packaging
echo ============================================================
echo.

echo [1/3] Preparing frontend assets...
if exist "%~dp0frontend\package.json" (
    cd /d "%~dp0frontend"
    call npm install --no-fund --no-audit
    if errorlevel 1 (
        echo [ERROR] Frontend dependency install failed.
        exit /b 1
    )

    call npm run build
    if errorlevel 1 (
        echo [ERROR] Frontend build failed.
        exit /b 1
    )
) else (
    echo   [WARN] frontend/package.json not found; skipping frontend build.
)

echo.
echo [2/3] Building standalone executable...
cd /d "%~dp0"

set DIST_DIR=%~dp0dist\publish
set BUILD_DIR=%~dp0build\pyinstaller

if exist "%DIST_DIR%\Lazy-Tube.exe" (
    echo [INFO] Closing running instances of Lazy-Tube.exe...
    taskkill /F /IM Lazy-Tube.exe >nul 2>&1
    timeout /t 1 /nobreak >nul
)

if exist "%DIST_DIR%" (
    rmdir /s /q "%DIST_DIR%" 2>nul
    if exist "%DIST_DIR%" (
        echo [ERROR] Could not remove existing dist folder. Ensure Lazy-Tube.exe is not running.
        exit /b 1
    )
)
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%" 2>nul
mkdir "%DIST_DIR%" 2>nul

"%PYTHON_EXE%" -m PyInstaller --noconfirm --clean --name Lazy-Tube --onefile --icon "%ICON_ICO%" --distpath "%DIST_DIR%" --workpath "%BUILD_DIR%" ^
  --add-data "frontend\dist;frontend\dist" ^
  --add-data "backend;backend" ^
  --collect-submodules api ^
  --collect-submodules core ^
  --collect-submodules skills ^
  --collect-submodules backend ^
  --hidden-import api ^
  --hidden-import core ^
  --hidden-import skills ^
  --hidden-import backend ^
  "%~dp0backend\main.py"
if errorlevel 1 (
    echo [ERROR] PyInstaller packaging failed.
    exit /b 1
)

echo.
echo [3/3] Copying default configurations and release files...
if not exist "%DIST_DIR%\config" mkdir "%DIST_DIR%\config"
if not exist "%DIST_DIR%\data" mkdir "%DIST_DIR%\data"

copy /Y "%~dp0data\brand_profile.yaml" "%DIST_DIR%\config\brand_profile.yaml"
copy /Y "%~dp0config\youtube_config.yaml" "%DIST_DIR%\config\youtube_config.yaml"
copy /Y "%~dp0config\ollama_config.yaml" "%DIST_DIR%\config\ollama_config.yaml"
copy /Y "%~dp0user-guide.md" "%DIST_DIR%\user-guide.md"

echo.
echo ============================================================
echo   Release bundle ready
echo ============================================================
echo.
echo   Executable: %DIST_DIR%\Lazy-Tube.exe
echo   Config Folder: %DIST_DIR%\config\
echo   Data Folder: %DIST_DIR%\data\
echo.
pause
ENDLOCAL
"@
Set-Content -Path (Join-Path $ProjectRoot "publish.bat") -Value $PublishBat -Encoding ASCII

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Success! Architectural changes have been applied." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1. Import 'settings_router' from 'backend.api.settings' inside your 'backend/main.py'."
Write-Host "2. Mount 'app.include_router(settings_router, prefix=\"/api\")' in 'backend/main.py'."
Write-Host "3. Import 'SettingsTab' into your React navigation UI."