# ============================================================
#  lazy-tube Starter (PowerShell 5.x compatible)
#  Starts backend + frontend in separate windows
#  Run:  powershell -ExecutionPolicy Bypass -File start.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "Starting lazy-tube..." -ForegroundColor Cyan
Write-Host "  Backend:  http://localhost:8000" -ForegroundColor Gray
Write-Host "  Frontend: http://localhost:5173 (Electron window opens automatically)" -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------
# Helper: launch a new PowerShell window with a custom title
# ---------------------------------------------------------
function Start-WindowedProcess {
    param(
        [string]$Title,
        [string]$WorkingDir,
        [string]$Command
    )

    # PS 5.x compatible: use cmd /c start to spawn a titled window
    # The new window runs powershell.exe with -NoExit so you can see logs
    $psArgs = @(
        "-NoExit"
        "-Command"
        "`$Host.UI.RawUI.WindowTitle = '$Title'; cd '$WorkingDir'; $Command"
    )

    Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -WorkingDirectory $WorkingDir
}

# ---------------------------------------------------------
# Backend (FastAPI)
# ---------------------------------------------------------
$backendCmd = @"
if (Test-Path .venv) {
    .\.venv\Scripts\Activate.ps1
} else {
    Write-Host 'Creating virtual environment...' -ForegroundColor Yellow
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    Write-Host 'Installing Python dependencies (one-time, may take a minute)...' -ForegroundColor Yellow
    pip install -r ..\requirements.txt
}
python main.py
"@

Start-WindowedProcess `
    -Title "lazy-tube Backend" `
    -WorkingDir "$root\backend" `
    -Command $backendCmd

# ---------------------------------------------------------
# Frontend (Vite + Electron)
# ---------------------------------------------------------
$frontendCmd = @"
if (-not (Test-Path node_modules)) {
    Write-Host 'Installing Node dependencies (one-time, may take a few minutes)...' -ForegroundColor Yellow
    npm install
}
npm run dev
"@

Start-WindowedProcess `
    -Title "lazy-tube Frontend" `
    -WorkingDir "$root\frontend" `
    -Command $frontendCmd

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
Write-Host "[OK] Both services launched." -ForegroundColor Green
Write-Host "     - Backend window:  'lazy-tube Backend' (port 8000)" -ForegroundColor Gray
Write-Host "     - Frontend window: 'lazy-tube Frontend' (Vite + Electron)" -ForegroundColor Gray
Write-Host ""
Write-Host "The Electron window will appear automatically once Vite is ready." -ForegroundColor Green
Write-Host "Close this window or press Ctrl+C to stop watching (services keep running)." -ForegroundColor Gray
Write-Host ""
Write-Host "To stop everything: close both spawned PowerShell windows." -ForegroundColor Yellow
Write-Host ""
