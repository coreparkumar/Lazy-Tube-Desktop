@echo off
echo ========================================
echo RUNNING CODE QUALITY ^& BUILD CHECK
echo ========================================
cd frontend
echo [*] Verifying frontend package dependencies...
call npm run build
if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Next.js Build Failed! Fix errors before committing.
  exit /b %ERRORLEVEL%
)
echo [SUCCESS] Build succeeded with zero compilation blocks.
