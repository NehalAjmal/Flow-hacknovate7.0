#!/bin/bash

echo "⚡ Cleaning up any old processes..."
pkill -f "uvicorn"
pkill -f "flutter run -d web-server"
sleep 1

echo "================================================="
echo " 🚀 LAUNCHING FLOW AI SYSTEM"
echo "================================================="

# Start Backend
echo "[1/2] Starting Python FastAPI Backend..."
source venv/bin/activate
cd Backend
uvicorn main:app --port 8002 --reload > ../backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Start Frontend
echo "[2/2] Starting Flutter Web Frontend..."
cd frontend
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 > ../frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

echo " "
echo "✅ FLOW is fully operational!"
echo " "
echo " 🟢 Frontend UI: http://127.0.0.1:8080"
echo " 🟢 Backend API: http://127.0.0.1:8002"
echo " "
echo "Logs are being saved to backend.log and frontend.log"
echo "Press [Ctrl+C] to stop both servers."
echo "================================================="

# Trap Ctrl+C (SIGINT) to cleanly kill both processes
trap "echo -e '\n🛑 Terminating FLOW...'; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" SIGINT SIGTERM

# Wait for background processes to keep script running
wait $BACKEND_PID $FRONTEND_PID
