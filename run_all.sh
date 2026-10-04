#!/bin/bash
# FLOW — launch backend (FastAPI :8002) + frontend (Flutter web :8080)
set -u
cd "$(dirname "$0")"

BACKEND_PORT=8002
FRONTEND_PORT=8080

kill_port() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids=$(lsof -ti tcp:"$port" 2>/dev/null)
    if [ -n "$pids" ]; then
      echo "   killing stale process(es) on port $port: $pids"
      kill $pids 2>/dev/null
      sleep 1
      pids=$(lsof -ti tcp:"$port" 2>/dev/null)
      [ -n "$pids" ] && kill -9 $pids 2>/dev/null
    fi
  fi
}

echo "⚡ Cleaning up any old processes..."
kill_port "$BACKEND_PORT"
kill_port "$FRONTEND_PORT"

if [ ! -d venv ]; then
  echo "❌ No venv/ found at repo root. Create one and install Backend/requirements.txt first:"
  echo "   python3 -m venv venv && source venv/bin/activate && pip install -r Backend/requirements.txt"
  exit 1
fi

echo "================================================="
echo " 🚀 LAUNCHING FLOW AI SYSTEM"
echo "================================================="

echo "[1/2] Starting Python FastAPI Backend..."
source venv/bin/activate
(cd Backend && uvicorn main:app --port "$BACKEND_PORT" > ../backend.log 2>&1) &
BACKEND_PID=$!
deactivate >/dev/null 2>&1 || true

# Wait for the backend to answer before starting the frontend
echo "   waiting for backend health..."
BACKEND_UP=0
for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:$BACKEND_PORT/api/ping" >/dev/null 2>&1; then
    BACKEND_UP=1
    break
  fi
  sleep 1
done

if [ "$BACKEND_UP" -ne 1 ]; then
  echo "❌ Backend failed to start on port $BACKEND_PORT. Last log lines:"
  tail -20 backend.log
  kill "$BACKEND_PID" 2>/dev/null
  exit 1
fi
echo "   backend is up ✓"

echo "[2/2] Starting Flutter Web Frontend..."
(cd frontend && flutter run -d web-server --web-hostname 127.0.0.1 --web-port "$FRONTEND_PORT") > frontend.log 2>&1 &
FRONTEND_PID=$!

# Give flutter a moment, then confirm it didn't die immediately
sleep 10
if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
  echo "❌ Frontend failed to start. Last log lines:"
  tail -20 frontend.log
  kill "$BACKEND_PID" 2>/dev/null
  exit 1
fi

echo " "
echo "✅ FLOW is fully operational!"
echo " "
echo " 🟢 Frontend UI: http://127.0.0.1:$FRONTEND_PORT"
echo " 🟢 Backend API: http://127.0.0.1:$BACKEND_PORT"
echo " "
echo "Logs are being saved to backend.log and frontend.log"
echo "Press [Ctrl+C] to stop both servers."
echo "================================================="

trap 'echo -e "\n🛑 Terminating FLOW..."; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit' SIGINT SIGTERM

# Exit loudly if either process dies while running
wait -n "$BACKEND_PID" "$FRONTEND_PID"
echo "❌ One of the FLOW processes exited unexpectedly — check backend.log / frontend.log"
kill "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null
exit 1
