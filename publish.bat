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

if exist "%~dp0data\brand_profile.yaml" (
    copy /Y "%~dp0data\brand_profile.yaml" "%DIST_DIR%\config\brand_profile.yaml"
    copy /Y "%~dp0data\brand_profile.yaml" "%DIST_DIR%\data\brand_profile.yaml"
)

copy /Y "%~dp0config\youtube_config.yaml" "%DIST_DIR%\config\youtube_config.yaml"
copy /Y "%~dp0config\ollama_config.yaml" "%DIST_DIR%\config\ollama_config.yaml"

if exist "%~dp0data\client_secrets.json" copy /Y "%~dp0data\client_secrets.json" "%DIST_DIR%\data\client_secrets.json"
if exist "%~dp0data\youtube_token.pickle" copy /Y "%~dp0data\youtube_token.pickle" "%DIST_DIR%\data\youtube_token.pickle"
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
