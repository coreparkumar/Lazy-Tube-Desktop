@echo off
REM ============================================================================
REM  lazy-tube Installer
REM  Installs Python + Node dependencies for both backend and frontend
REM  Idempotent: safe to re-run
REM  Run:  install.bat
REM ============================================================================

setlocal EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo ============================================================
echo   lazy-tube Installer
echo ============================================================
echo.

REM ---------------------------------------------------------
REM 1. Check prerequisites
REM ---------------------------------------------------------
echo [1/4] Checking prerequisites...
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    echo         Download from: https://python.org/downloads
    echo         During install, CHECK "Add Python to PATH"
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('python --version') do echo   [OK] %%v

REM Check pip
python -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] pip is not available. Reinstall Python with pip enabled.
    pause
    exit /b 1
)
echo   [OK] pip

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not in PATH.
    echo         Download from: https://nodejs.org
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('node --version') do echo   [OK] %%v

REM Check npm
npm --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm is not available. Reinstall Node.js.
    pause
    exit /b 1
)
echo   [OK] npm

REM Check Ollama (warn only - can be installed later)
ollama --version >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Ollama not found. Install from https://ollama.com
    echo          You can run lazy-tube UI without it, but generation will fail.
) else (
    for /f "tokens=*" %%v in ('ollama --version') do echo   [OK] %%v
)
echo.

REM ---------------------------------------------------------
REM 2. Backend - Python virtual environment + dependencies
REM ---------------------------------------------------------
echo [2/4] Setting up Python backend...
echo.

if not exist "backend" (
    echo [ERROR] backend\ folder not found. Run setup.ps1 first.
    pause
    exit /b 1
)

cd /d "%~dp0backend"

REM Create venv if missing
if not exist ".venv" (
    echo   Creating virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo   [ERROR] Failed to create venv
        pause
        exit /b 1
    )
    echo   [OK] Virtual environment created
) else (
    echo   [OK] Virtual environment already exists
)

REM Activate venv
call .venv\Scripts\activate.bat
if errorlevel 1 (
    echo   [ERROR] Failed to activate venv
    pause
    exit /b 1
)

REM Upgrade pip
echo   Upgrading pip...
python -m pip install --upgrade pip --quiet --disable-pip-version-check
echo   [OK] pip upgraded

REM Install/upgrade requirements
echo   Installing requirements from ..\requirements.txt ...
echo   (This may take 1-2 minutes on first run)
echo.

pip install -r ..\requirements.txt --upgrade --disable-pip-version-check
if errorlevel 1 (
    echo.
    echo   [ERROR] pip install failed. See output above.
    pause
    exit /b 1
)
echo.
echo   [OK] Python dependencies installed
echo.

REM Verify critical imports
echo   Verifying critical imports...
python -c "import fastapi, uvicorn, httpx, yaml, googleapiclient" 2>nul
if errorlevel 1 (
    echo   [ERROR] Critical imports failed. Check pip output above.
    pause
    exit /b 1
)
echo   [OK] All critical imports working
echo.

REM Deactivate
call deactivate

cd /d "%~dp0"

REM ---------------------------------------------------------
REM 3. Frontend - Node dependencies
REM ---------------------------------------------------------
echo [3/4] Setting up Node frontend...
echo.

if not exist "frontend" (
    echo [ERROR] frontend\ folder not found. Run setup.ps1 first.
    pause
    exit /b 1
)

cd /d "%~dp0frontend"

REM Install if node_modules missing OR package.json is newer
if not exist "node_modules" (
    echo   node_modules not found. Running npm install...
    echo   (This may take 2-5 minutes on first run)
    echo.
    call npm install
    if errorlevel 1 (
        echo.
        echo   [ERROR] npm install failed. See output above.
        pause
        exit /b 1
    )
    echo.
    echo   [OK] Node dependencies installed
) else (
    echo   node_modules exists. Checking if reinstall needed...
    REM Check if package.json is newer than node_modules
    for %%f in (package.json) do set "pkg_time=%%~tf"
    REM Simple check: just run install to be safe
    echo   Running npm install to ensure everything is up-to-date...
    call npm install --silent
    if errorlevel 1 (
        echo   [WARN] npm install had warnings (non-fatal)
    ) else (
        echo   [OK] Node dependencies up-to-date
    )
)
echo.

REM Verify Vite installed
if not exist "node_modules\.bin\vite.cmd" (
    echo   [ERROR] Vite not installed. npm install may have failed.
    pause
    exit /b 1
)
echo   [OK] Vite is installed
echo.

cd /d "%~dp0"

REM ---------------------------------------------------------
REM 4. Final checks + summary
REM ---------------------------------------------------------
echo [4/4] Final verification...
echo.

REM Check brand profile
if not exist "data\brand_profile.yaml" (
    echo   [WARN] data\brand_profile.yaml is missing!
    echo          Create it from the template before running lazy-tube.
) else (
    echo   [OK] brand_profile.yaml exists
)

REM Check YouTube secrets (warn only)
if not exist "data\client_secrets.json" (
    echo   [INFO] data\client_secrets.json not found
    echo          You'll need this to upload videos. See api-guide.md.
) else (
    echo   [OK] client_secrets.json exists
)

echo.
echo ============================================================
echo   Installation complete!
echo ============================================================
echo.
echo   Next steps:
echo.
echo   1. Make sure Ollama is running (in a separate terminal):
echo        ollama serve
echo.
echo   2. Pull the models (one-time, downloads several GB):
echo        ollama pull llama3.1
echo        ollama pull mistral
echo.
echo   3. Edit your brand profile:
echo        notepad data\brand_profile.yaml
echo.
echo   4. Start the app:
echo        start.bat           (or .\start.ps1)
echo.
echo ============================================================
echo.

pause
