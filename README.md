# 🌊 Flow: AI-Powered Developer Fatigue Monitor

**Flow** is an intelligent system designed to monitor and mitigate developer fatigue using real-time AI analysis. Built by **Team Error 011** for **Hacknovate 7.0**, Flow acts as an AI-powered cognitive alignment system. This project features a **premium Flutter Windows** desktop frontend and a robust **Python (FastAPI)** backend.

## ✨ Key Features
* **Real-Time Biometric Tracking**: Uses computer vision (MediaPipe & OpenCV) to monitor physical fatigue signs.
* **Desktop Activity Monitoring**: Tracks context switching and application usage to identify passive consumption or distraction.
* **AI-Powered Interventions**: Provides smart, context-aware nudges based on your current state (e.g., *Fatigued*, *Stuck*, *Passive*, *Distracted*, or *Deep Work*).
* **Ultradian Rhythm Tracking**: Learns your natural focus cycles and suggests breaks at your biological natural break points.
* **Calendar Integration**: Analyzes your schedule to warn you against starting deep work right before an upcoming meeting.
* **Focus DNA & Session Export**: Export your session data to understand your long-term focus patterns and cognitive rhythms.

---

## 🏗 Project Structure
```text
Flow-hacknovate7.0/
├── .env              # Global environment variables (Root folder)
├── Backend/          # FastAPI server, ML models, & Database logic
├── frontend/         # Flutter Windows application
└── README.md
```

---

## 🚀 Installation & Setup

### **1. Global Configuration**
Create a file named `.env` in the **root directory** (`Flow-hacknovate7.0/`). A ready-made template is provided:

```bash
cp .env.example .env
```

Then edit `.env` and fill in your real values:

```env
JWT_SECRET_KEY=<generate-a-random-hex-string>
DATABASE_URL=mysql+pymysql://root:YOURPWD@localhost/flow_db
GEMINI_API_KEY=<your-gemini-api-key>
GOOGLE_CLIENT_ID=<your-google-client-id>
```

> **Tip:** Generate a JWT secret with `python -c "import secrets; print(secrets.token_hex(32))"`
> Get a Gemini API key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey)


### **2. Backend Setup (Python)**
1.  **Navigate to the backend folder:**
    ```powershell
    cd Backend
    ```
2.  **Create and activate a virtual environment:**
    ```powershell
    python -m venv venv
    .\venv\Scripts\activate
    ```
3.  **Install Dependencies:**
    ```powershell
    pip install -r requirements.txt
    ```
4.  **Run Setup Script:**
    ```powershell
    python setup.py install
    ```
5.  **Database Preparation:** Ensure MySQL is running and create the database:
    ```sql
    CREATE DATABASE flow_db;
    ```
6.  **Start the Server:**
    ```powershell
    uvicorn main:app --reload --port 8000
    ```

### **3. Frontend Setup (Flutter Windows)**
1.  **Navigate to the frontend folder:**
    ```powershell
    cd frontend
    ```
2.  **Install Flutter dependencies:**
    ```powershell
    flutter pub get
    ```
3.  **Run the application:**
    ```powershell
    flutter run -d windows
    ```

---

## 🛠 Tech Stack
* **Frontend:** Flutter (Dart) with premium typography (Sora & DM Mono)
* **Backend:** FastAPI (Python)
* **Database:** MySQL (via SQLAlchemy)
* **AI & Vision:** Google Gemini API, MediaPipe, OpenCV
* **Desktop Activity:** `pynput`, platform-specific APIs (`pywin32` / `pyobjc`)
* **Authentication:** JWT & Google OAuth 2.0

---

## ⚠️ Security Note
The `.env` file contains sensitive API keys and database credentials. **Never commit the `.env` file to version control.** It is recommended to add `.env` to your `.gitignore` file immediately.

---

**Quick Tip:** If you run into issues with the MySQL connection, double-check that your `DATABASE_URL` in the `.env` file matches your local MySQL port (usually `3306`) and that the `pymysql` driver is installed during the requirements step!
