@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
title lazy-tube - Frontend

echo ==================================
echo         Frontend Service
echo ==================================
echo.

REM --------------------------------------------------
REM 1. Wait for Backend
REM --------------------------------------------------
echo Waiting for backend to become available...
SET WAIT_COUNT=0
SET MAX_WAIT_COUNT=90

:WAIT_BACKEND
timeout /t 2 >nul

curl -s http://127.0.0.1:8000/health >nul 2>nul

IF %ERRORLEVEL% EQU 0 (
    echo Backend detected.
    GOTO START_FRONTEND
)

SET /A WAIT_COUNT+=1

IF !WAIT_COUNT! GEQ !MAX_WAIT_COUNT! (
    echo Backend did not start within expected time.
    pause
    exit /b
)

echo Backend not ready yet... retrying...
GOTO WAIT_BACKEND

REM --------------------------------------------------
REM 2. Start Vite + Electron (from frontend dir)
REM --------------------------------------------------
:START_FRONTEND
echo.
cd /d "%~dp0frontend"

IF NOT EXIST "node_modules" (
    echo Installing frontend dependencies...
    call npm install
    if errorlevel 1 (
      echo npm install failed. Frontend will not start.
      pause
      exit /b 1
    )
) ELSE (
    echo Frontend dependencies already installed.
)

echo Starting Vite + Electron...
call npm run dev

ENDLOCAL
