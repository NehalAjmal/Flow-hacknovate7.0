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
Create a file named `.env` in the **root directory** (`Flow-hacknovate7.0/`) and paste the following template. **Note:** Replace `YOURPWD` with your actual MySQL root password and `your_api` with your actual Gemini api key.

```env
JWT_SECRET_KEY=9cd55c27863892dc733d7f0a708a4c5b67c6d2dc6c463c80b9b65d9e8a4103a4
DATABASE_URL=mysql+pymysql://root:YOURPWD@localhost/flow_db
GEMINI_API_KEY=your_api
GOOGLE_CLIENT_ID="107877434537-gajs6tph673aaoi9p6obkh232og8kutf.apps.googleusercontent.com"
```

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
