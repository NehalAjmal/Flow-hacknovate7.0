-- ============================================================
-- FLOW — AI-Powered Cognitive Alignment System
-- MySQL Schema
-- Team Error 011 | Hacknovate 7.0
-- ============================================================

-- teams must exist before users (FK dependency)
CREATE TABLE teams (
  id           VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name         VARCHAR(255) NOT NULL,
  company_code VARCHAR(16) UNIQUE NOT NULL,
  admin_key    VARCHAR(255) NOT NULL,  -- bcrypt hashed 6-digit code
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- users
CREATE TABLE users (
  id              VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  full_name       VARCHAR(255) NOT NULL,
  email           VARCHAR(320) UNIQUE NOT NULL,
  password_hash   VARCHAR(255) NOT NULL,
  age             INT NULL,
  sex             VARCHAR(20) NULL,             -- male | female | prefer_not_to_say
  role            VARCHAR(20) DEFAULT 'solo',   -- solo | employee | admin
  team_id         VARCHAR(36) NULL,
  pattern_model   JSON,                         -- learning engine writes here after every session
  burnout_flagged BOOLEAN DEFAULT false,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (team_id) REFERENCES teams(id)
);

-- sessions
CREATE TABLE sessions (
  id                     VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id                VARCHAR(36),
  task_description       TEXT,
  declared_difficulty    VARCHAR(50),
  planned_duration_min   INT,
  actual_duration_min    INT,
  start_time             TIMESTAMP NULL,
  end_time               TIMESTAMP NULL,
  focus_score            INT,
  self_rated_quality     INT,
  interventions_total    INT DEFAULT 0,
  interventions_accepted INT DEFAULT 0,
  signal_log             JSON,    -- raw 30s agent ticks
  replay_events          JSON,    -- processed stream for Flutter replay component
  learned_updates        JSON,    -- what the learning engine updated in pattern_model
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- biometric_readings
CREATE TABLE biometric_readings (
  id            VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id       VARCHAR(36),
  session_id    VARCHAR(36),
  heart_rate_bpm FLOAT,
  hrv_sdnn      FLOAT,
  ear_value     FLOAT,   -- Eye Aspect Ratio from dlib (0-1)
  source        VARCHAR(50),    -- apple_watch | webcam_rppg
  confidence    FLOAT,
  recorded_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- breaks
CREATE TABLE breaks (
  id                  VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  session_id          VARCHAR(36),
  suggested_at        TIMESTAMP NULL,
  taken               BOOLEAN DEFAULT false,
  taken_at            TIMESTAMP NULL,
  duration_actual_min INT,
  switches_before     FLOAT,   -- Layer A: pre-break state
  switches_after      FLOAT,   -- Layer B: post-break state
  keystrokes_before   FLOAT,
  keystrokes_after    FLOAT,
  restoration_score   FLOAT,   -- 0-1, computed on break end
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- calendar_cache
-- Local copy of Google Calendar events. Refreshed at session pre-check.
-- UPSERT on (user_id, event_id) so re-fetching never duplicates rows.
CREATE TABLE calendar_cache (
  id          VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id     VARCHAR(36),
  event_id    VARCHAR(255) NOT NULL,
  title       VARCHAR(255),
  starts_at   TIMESTAMP NOT NULL,
  ends_at     TIMESTAMP NOT NULL,
  is_blocking BOOLEAN DEFAULT false,
  fetched_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (user_id, event_id)
);

-- llm_cache
-- Keyed by deterministic context hash. No FK to users — responses are reusable across users.
-- expires_at = NULL means pre-baked demo response, never expires.
CREATE TABLE llm_cache (
  id            VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  cache_key     VARCHAR(255) UNIQUE NOT NULL,
  prompt_type   VARCHAR(50) NOT NULL,  -- intervention | stuck | focus_dna | forecast_insight
  prompt_text   TEXT NOT NULL,
  response_text TEXT NOT NULL,
  expires_at    TIMESTAMP NULL,
  hit_count     INT DEFAULT 0,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- Demo seed — ERR011 team for DEMO_MODE
-- ============================================================
INSERT INTO teams (name, company_code, admin_key)
VALUES ('Error 011 Demo Corp', 'ERR011', '$2b$12$placeholderHashReplaceBeforeDemo');