@echo off
echo ========================================
echo   Syncing with GitHub
echo ========================================

echo Fetching latest...
git fetch origin

echo.
echo Checking status...
git status

echo.
set /p choice="Pull (p) / Push (u) / Both (b)? "
if /i "%choice%"=="p" goto :pull
if /i "%choice%"=="u" goto :push
if /i "%choice%"=="b" goto :both
goto :end

:both
git reset --hard origin/main
git clean -fd
echo Local synced with GitHub.

:push
set /p msg="Commit message: "
if "%msg%"=="" set msg="Update %date% %time%"
git add .
git commit -m "%msg%"
git push -u origin main
goto :end

:pull
git reset --hard origin/main
git clean -fd

:end
echo.
echo ========================================
echo   Sync complete!
echo ========================================
pause
