@echo off
echo ========================================
echo   Undo Last Commit
echo ========================================
echo.
echo Options:
echo   1. Soft reset (keep changes staged)
echo   2. Mixed reset (unstage changes)
echo   3. Hard reset (DELETE changes!)
echo.
set /p choice="Choose (1/2/3): "

if "%choice%"=="1" git reset --soft HEAD~1
if "%choice%"=="2" git reset HEAD~1
if "%choice%"=="3" (
    set /p confirm="Are you SURE? This deletes everything! (yes/no): "
    if /i "%confirm%"=="yes" git reset --hard HEAD~1
)

echo.
echo Done! Current status:
git status
pause
