#!/bin/bash

# Kill any existing uvicorn processes
pkill -f uvicorn

# Wait a moment for processes to terminate
sleep 1

# Start the server
cd /Users/nehalajmal/Flow-hacknovate7.0/Backend
python3.11 -m uvicorn main:app --reload --port 8002