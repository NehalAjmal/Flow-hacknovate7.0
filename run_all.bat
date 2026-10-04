@echo off
REM FLOW - launch backend (FastAPI :8002) + frontend (Flutter web :8080) on Windows
setlocal enabledelayedexpansion
cd /d "%~dp0"

set BACKEND_PORT=8002
set FRONTEND_PORT=8080

echo ================================================
echo  LAUNCHING FLOW AI SYSTEM
echo ================================================

if not exist venv\Scripts\activate.bat (
  echo ❌ No venv\ found at repo root. Create one first:
  echo    python -m venv venv ^&^& venv\Scripts\activate ^&^& pip install -r Backend\requirements.txt
  goto :fail
)

echo [1/2] Starting Python FastAPI Backend...
call venv\Scripts\activate.bat
start "FLOW backend" /D Backend cmd /c "uvicorn main:app --port %BACKEND_PORT% > ..\backend.log 2>&1"
deactivate

echo    waiting for backend health...
set BACKEND_UP=0
for /l %%i in (1,1,30) do (
  if !BACKEND_UP!==0 (
    curl -sf http://127.0.0.1:%BACKEND_PORT%/api/ping >nul 2>&1 && set BACKEND_UP=1
    if !BACKEND_UP!==0 timeout /t 1 /nobreak >nul
  )
)
if not %BACKEND_UP%==1 (
  echo ❌ Backend failed to start on port %BACKEND_PORT%. Last log lines:
  powershell -Command "Get-Content backend.log -Tail 20"
  goto :fail
)
echo    backend is up ✓

echo [2/2] Starting Flutter Web Frontend...
start "FLOW frontend" /D frontend cmd /c "flutter run -d web-server --web-hostname 127.0.0.1 --web-port %FRONTEND_PORT% > ..\frontend.log 2>&1"

echo.
echo ✅ FLOW is fully operational!
echo.
echo  🟢 Frontend UI: http://127.0.0.1:%FRONTEND_PORT%
echo  🟢 Backend API: http://127.0.0.1:%BACKEND_PORT%
echo.
echo Logs: backend.log, frontend.log. Close the two server windows to stop.
goto :eof

:fail
echo.
echo ❌ FLOW failed to launch.
pause
exit /b 1
