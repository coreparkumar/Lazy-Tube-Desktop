@echo off
echo ========================================
echo   Initializing Git Repository
echo ========================================

git init
git branch -M main
git remote add origin %1

if errorlevel 1 (
    echo Remote already exists. Updating...
    git remote set-url origin %1
)

echo.
echo ========================================
echo   Git initialized!
echo ========================================
echo Remote: %1
git remote -v
pause
