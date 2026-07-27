@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

cd /d "%~dp0backend"
title lazy-tube - Backend

echo ==================================
echo         Backend Service
echo ==================================
echo.

REM --------------------------------------------------
REM 1. Kill any process using port 8000
REM --------------------------------------------------
echo Cleaning port 8000 if in use...
FOR /F "tokens=5" %%A IN ('netstat -ano ^| findstr :8000') DO (
    echo Killing process on port 8000 (PID %%A)
    taskkill /PID %%A /F >nul 2>nul
)

REM --------------------------------------------------
REM 2. Ensure virtual environment exists
REM --------------------------------------------------
IF NOT EXIST ".venv" (
    echo Creating virtual environment...
    python -m venv .venv
)

REM --------------------------------------------------
REM 3. Install dependencies only when required
REM --------------------------------------------------
echo Checking backend dependencies...
.venv\Scripts\python.exe -c "import fastapi, uvicorn, pydantic, pydantic_settings, requests, httpx, yaml, googleapiclient" >nul 2>nul
IF ERRORLEVEL 1 (
    echo Installing backend dependencies...
    .venv\Scripts\python.exe -m pip install --upgrade pip >nul

    IF EXIST "..\requirements.txt" (
        .venv\Scripts\pip.exe install -r ..\requirements.txt
    ) ELSE (
        echo requirements.txt not found in project root.
    )

    REM Ensure critical packages (safety net, Megamind-style)
    .venv\Scripts\pip.exe install ^
        fastapi ^
        uvicorn[standard] ^
        pydantic ^
        pydantic-settings ^
        requests ^
        httpx ^
        pyyaml ^
        google-api-python-client ^
        google-auth-oauthlib ^
        google-auth-httplib2 >nul
) ELSE (
    echo Backend dependencies are already available.
)

REM --------------------------------------------------
REM 4. Verify Ollama is reachable
REM --------------------------------------------------
echo.
echo Checking Ollama on http://localhost:11434 ...
curl -s -m 3 http://localhost:11434 >nul 2>&1
IF ERRORLEVEL 1 (
    echo [WARN] Ollama is not running on port 11434.
    echo        Start it in another terminal: ollama serve
    echo        Generation will fail until Ollama is up.
) ELSE (
    echo [OK] Ollama is reachable.
)

REM --------------------------------------------------
REM 5. Verify brand profile exists
REM --------------------------------------------------
IF NOT EXIST "..\data\brand_profile.yaml" (
    echo [WARN] ..\data\brand_profile.yaml not found.
    echo        Edit it before generating metadata.
)

REM --------------------------------------------------
REM 6. Start FastAPI
REM --------------------------------------------------
echo.
echo Starting FastAPI on http://127.0.0.1:8000
echo API docs: http://127.0.0.1:8000/docs
echo.

.venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload

ENDLOCAL
