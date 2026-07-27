@echo off
SETLOCAL EnableDelayedExpansion

cd /d "%~dp0"
title lazy-tube - Runner

echo ==================================
echo      lazy-tube Runner
echo ==================================
echo.

:CHOOSE_MODE
echo Select startup mode:
echo   [1] UI mode (Electron + backend)
echo   [2] Service mode (backend only)
set /p "START_MODE=Enter 1 or 2: "

if /I "%START_MODE%"=="1" (
    set "START_MODE=UI"
    goto MODE_SELECTED
)

if /I "%START_MODE%"=="2" (
    set "START_MODE=SERVICE"
    goto MODE_SELECTED
)

echo [ERROR] Invalid choice. Please enter 1 or 2.
echo.
goto CHOOSE_MODE

:MODE_SELECTED
echo [*] Selected mode: %START_MODE%
echo.

REM ---------------------------------------------------------
REM Load configuration from .env if it exists
REM ---------------------------------------------------------
set "MODEL_NAME=llama3.1"
set "FALLBACK_MODEL=mistral"
set "OLLAMA_BASE_URL=http://localhost:11434"
set "BACKEND_URL=http://127.0.0.1:8000"

if exist ".env" (
    echo [*] Reading configuration from .env ...
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        if /I "%%~A"=="OLLAMA_MODEL" set "MODEL_NAME=%%~B"
        if /I "%%~A"=="OLLAMA_URL" set "OLLAMA_BASE_URL=%%~B"
        if /I "%%~A"=="BACKEND_URL" set "BACKEND_URL=%%~B"
    )
)

echo     Model:        %MODEL_NAME%
echo     Fallback:     %FALLBACK_MODEL%
echo     Ollama URL:   %OLLAMA_BASE_URL%
echo     Backend URL:  %BACKEND_URL%
echo.

REM 0. Clear Ollama VRAM before anything else
echo [*] Clearing Ollama memory (%MODEL_NAME%)...
ollama stop "%MODEL_NAME%" >nul 2>nul
timeout /t 2 /nobreak >nul

REM 1. Check if Ollama is installed
where ollama >nul 2>nul
if errorlevel 1 (
    echo [!] Ollama not found in PATH.
    echo     Download from: https://ollama.com
    powershell -Command "[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')|Out-Null;[System.Windows.Forms.MessageBox]::Show('Ollama is not installed. Download at https://ollama.com', 'Ollama Missing', 0, 64)"
    pause
    exit /b 1
)

REM 2. Restart Ollama and wait for it to become healthy
echo [*] Restarting Ollama service...
taskkill /IM ollama.exe /F >nul 2>nul
timeout /t 3 /nobreak >nul
start "" ollama app

echo [*] Waiting for Ollama on %OLLAMA_BASE_URL%/api/tags ...
set "OLLAMA_WAIT_COUNT=0"
set "OLLAMA_MAX_WAIT_COUNT=45"

:WAIT_OLLAMA
timeout /t 2 /nobreak >nul
curl -s %OLLAMA_BASE_URL%/api/tags >nul 2>nul

if !ERRORLEVEL! EQU 0 (
    echo [*] Ollama is ready.
    goto OLLAMA_READY
)

set /A OLLAMA_WAIT_COUNT+=1
if !OLLAMA_WAIT_COUNT! GEQ !OLLAMA_MAX_WAIT_COUNT! (
    echo [ERROR] Ollama did not become ready in time.
    pause
    exit /b 1
)

echo [*] Ollama not ready yet... retrying...
goto WAIT_OLLAMA

:OLLAMA_READY

REM 3. Ensure required models are present (lazy pull)
echo.
echo [*] Checking installed models ...
ollama list > "%TEMP%\ollama_list.txt" 2>nul

set "MODEL_PRESENT=0"
findstr /I "%MODEL_NAME%" "%TEMP%\ollama_list.txt" >nul 2>nul
IF NOT ERRORLEVEL 1 (
    set "MODEL_PRESENT=1"
)

IF "%MODEL_PRESENT%"=="0" (
    echo [*] Model "%MODEL_NAME%" not found. Pulling from registry ...
    ollama pull "%MODEL_NAME%"
    if errorlevel 1 (
        echo [ERROR] Failed to pull "%MODEL_NAME%". Check your internet connection.
        pause
        exit /b 1
    )
) ELSE (
    echo [OK] "%MODEL_NAME%" is already installed.
)

findstr /I "%FALLBACK_MODEL%" "%TEMP%\ollama_list.txt" >nul 2>nul
IF ERRORLEVEL 1 (
    echo [*] Fallback "%FALLBACK_MODEL%" not found. Pulling ...
    ollama pull "%FALLBACK_MODEL%" >nul 2>nul
    if errorlevel 1 (
        echo [WARN] Could not pull fallback "%FALLBACK_MODEL%". Continuing without it.
    ) else (
        echo [OK] "%FALLBACK_MODEL%" installed.
    )
) ELSE (
    echo [OK] "%FALLBACK_MODEL%" already installed.
)

del "%TEMP%\ollama_list.txt" >nul 2>nul
echo.

REM 4. Cleanup existing processes
echo [*] Cleaning up existing processes ...
for /f "tokens=5" %%A in ('netstat -ano ^| findstr :8000') do taskkill /PID %%A /F >nul 2>nul
taskkill /IM electron.exe /F >nul 2>nul
echo.

REM 5. Start services
if /I "%START_MODE%"=="SERVICE" goto START_SERVICE

echo [*] Starting backend ...
start "lazy-tube Backend" cmd /k "cd /d %~dp0 && backend.bat"

echo [*] Waiting for backend on %BACKEND_URL%/health ...
set "WAIT_COUNT=0"
set "MAX_WAIT_COUNT=90"

:WAIT_BACKEND
timeout /t 2 >nul
curl -s %BACKEND_URL%/health >nul 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [*] Backend is ready. Starting frontend ...
    start "lazy-tube Frontend" cmd /k "cd /d %~dp0 && frontend.bat"
    goto STARTUP_DONE
)

set /A WAIT_COUNT+=1
if !WAIT_COUNT! GEQ !MAX_WAIT_COUNT! (
    echo [ERROR] Backend did not become ready in time. Frontend was not started.
    pause
    exit /b 1
)

echo [*] Backend not ready yet... retrying...
goto WAIT_BACKEND

:START_SERVICE
echo [*] Starting service mode (backend only) ...
start "lazy-tube Backend" cmd /k "cd /d %~dp0 && backend.bat"
goto STARTUP_DONE

:STARTUP_DONE

echo.
echo ==================================
echo   lazy-tube is running in %START_MODE% mode
echo ==================================
echo.
echo   Backend:  %BACKEND_URL%
echo   API docs: %BACKEND_URL%/docs
echo.
if /I "%START_MODE%"=="UI" (
    echo   The Electron window will open shortly.
    echo.
)
echo   To stop: close the spawned Backend (and Frontend) windows.
echo.

ENDLOCAL
