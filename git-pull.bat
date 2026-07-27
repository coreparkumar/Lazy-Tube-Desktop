@echo off
echo ========================================
echo   Pulling from GitHub
echo ========================================

echo.
echo Fetching latest...
git fetch origin

echo.
echo Resetting to match GitHub...
git reset --hard origin/main

echo Cleaning untracked files...
git clean -fd

echo.
echo ========================================
echo   Local now matches GitHub!
echo ========================================
git log --oneline -5
pause
