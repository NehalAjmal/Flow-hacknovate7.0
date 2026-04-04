
# 🌊 Flow: AI-Powered Developer Fatigue Monitor

**Flow** is an intelligent system designed to monitor and mitigate developer fatigue using real-time AI analysis. This project features a **Flutter Windows** desktop frontend and a **Python (FastAPI)** backend.

## 🏗 Project Structure
```text
Flow-hacknovate7.0/
├── .env              # Global environment variables (Root folder)
├── backend/          # FastAPI server, ML models, & Database logic
├── frontend/         # Flutter Windows application
└── README.md
```

---

## 🚀 Installation & Setup

### **1. Global Configuration**
Create a file named `.env` in the **root directory** (`Flow-hacknovate7.0/`) and paste the following template. **Note:** Replace `YOURPWD` with your actual MySQL root password.

```env
JWT_SECRET_KEY=9cd55c27863892dc733d7f0a708a4c5b67c6d2dc6c463c80b9b65d9e8a4103a4
DATABASE_URL=mysql+pymysql://root:YOURPWD@localhost/flow_db
GEMINI_API_KEY=AIzaSyD4YwmLcKSMw251v34VWCuLIhBYrbfoBeI
GOOGLE_CLIENT_ID="107877434537-gajs6tph673aaoi9p6obkh232og8kutf.apps.googleusercontent.com"
```

### **2. Backend Setup (Python)**
1.  **Navigate to the backend folder:**
    ```powershell
    cd backend
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
* **Frontend:** Flutter (Dart)
* **Backend:** FastAPI (Python)
* **Database:** MySQL (via SQLAlchemy)
* **AI Integration:** Google Gemini API
* **Authentication:** JWT & Google OAuth 2.0

---

## ⚠️ Security Note
The `.env` file contains sensitive API keys and database credentials. **Never commit the `.env` file to version control.** It is recommended to add `.env` to your `.gitignore` file immediately.

---

**Quick Tip:** If you run into issues with the MySQL connection, double-check that your `DATABASE_URL` in the `.env` file matches your local MySQL port (usually `3306`) and that the `pymysql` driver is installed during the requirements step!
