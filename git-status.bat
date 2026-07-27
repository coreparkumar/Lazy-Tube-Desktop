@echo off
echo ========================================
echo   Git Status
echo ========================================
echo.
echo Current branch:
git branch --show-current
echo.
echo Remote URL:
git remote -v
echo.
echo Last 5 commits:
git log --oneline -5
echo.
echo Current status:
git status
echo.
pause
