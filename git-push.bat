@echo off
echo ========================================
echo   Quick Push to GitHub
echo ========================================

set /p msg="Commit message: "
if "%msg%"=="" set msg="Update %date% %time%"

echo.
echo Adding files...
git add .

echo.
echo Committing: %msg%
git commit -m "%msg%"

echo.
echo Pushing to GitHub...
git push -u origin main

if errorlevel 1 (
    echo.
    echo ========================================
    echo   Push failed! Trying force push...
    echo ========================================
    set /p force="Force push? (y/n): "
    if /i "%force%"=="y" git push -u origin main --force
)

echo.
echo ========================================
echo   Done!
echo ========================================
pause
