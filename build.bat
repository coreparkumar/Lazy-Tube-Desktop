@echo off
SETLOCAL EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo ============================================================
echo   lazy-tube Fresh Build
echo ============================================================
echo.

REM ---------------------------------------------------------
REM 1. Verify prerequisites
REM ---------------------------------------------------------
echo [1/4] Checking prerequisites...
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    echo         Install Python and enable it in PATH.
    pause
    exit /b 1
)

node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not in PATH.
    echo         Install Node.js from https://nodejs.org.
    pause
    exit /b 1
)
echo   [OK] Python and Node.js available.
echo.

REM ---------------------------------------------------------
REM 2. Backend dependency install
REM ---------------------------------------------------------
echo [2/4] Building backend...
cd /d "%~dp0backend"

if not exist ".venv" (
    echo   Creating backend virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo   [ERROR] Failed to create backend virtual environment.
        pause
        exit /b 1
    )
)

call .venv\Scripts\activate.bat
if errorlevel 1 (
    echo   [ERROR] Failed to activate backend virtual environment.
    pause
    exit /b 1
)

echo   Upgrading pip...
python -m pip install --upgrade pip --disable-pip-version-check
if errorlevel 1 (
    echo   [ERROR] Failed to upgrade pip.
    call deactivate
    pause
    exit /b 1
)

echo   Installing backend requirements...
if exist "..\requirements.txt" (
    python -m pip install -r ..\requirements.txt --upgrade --disable-pip-version-check
) else (
    echo   [ERROR] requirements.txt not found in project root.
    call deactivate
    pause
    exit /b 1
)
if errorlevel 1 (
    echo   [ERROR] Backend dependency install failed.
    call deactivate
    pause
    exit /b 1
)

echo   [OK] Backend dependencies installed.
call deactivate

REM ---------------------------------------------------------
REM 3. Frontend dependency install + build
REM ---------------------------------------------------------
echo.
echo [3/4] Building frontend...
cd /d "%~dp0frontend"

echo   Installing frontend dependencies...
call npm install
if errorlevel 1 (
    echo   [ERROR] Frontend npm install failed.
    pause
    exit /b 1
)

echo   Building frontend assets...
call npm run build
if errorlevel 1 (
    echo   [ERROR] Frontend build failed.
    pause
    exit /b 1
)
echo   [OK] Frontend build complete.

REM ---------------------------------------------------------
REM 4. Finish
REM ---------------------------------------------------------
echo.
echo ============================================================
echo   Build complete! 
echo ============================================================
echo.
echo   Backend: %~dp0backend\.venv
echo   Frontend build output: %~dp0frontend\dist
echo.
pause
ENDLOCAL
