-- ============================================
-- DBA Counseling — Supabase Database Schema
-- Run this in Supabase SQL Editor
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLES
-- ============================================

-- Patients / Portal Users
CREATE TABLE patients (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT UNIQUE NOT NULL,
  full_name     TEXT NOT NULL,
  phone         TEXT,
  access_code   TEXT UNIQUE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  last_login    TIMESTAMPTZ
);

-- Sessions
CREATE TYPE session_type AS ENUM ('virtual', 'in-person', 'spiritual-direction');
CREATE TYPE session_status AS ENUM ('requested', 'confirmed', 'completed', 'cancelled');

CREATE TABLE sessions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id    UUID REFERENCES patients(id) ON DELETE CASCADE,
  type          session_type NOT NULL,
  status        session_status DEFAULT 'requested',
  scheduled_at  TIMESTAMPTZ,
  duration_min  INT DEFAULT 50,
  meeting_link  TEXT,
  location      TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Messages
CREATE TYPE message_sender AS ENUM ('patient', 'counselor');

CREATE TABLE messages (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id    UUID REFERENCES patients(id) ON DELETE CASCADE,
  sender        message_sender NOT NULL,
  content       TEXT NOT NULL,
  read          BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Resources
CREATE TYPE resource_type AS ENUM ('pdf', 'video', 'audio', 'link');

CREATE TABLE resources (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title         TEXT NOT NULL,
  type          resource_type NOT NULL,
  url           TEXT NOT NULL,
  description   TEXT,
  shared_with   UUID[] DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Donations
CREATE TYPE donation_platform AS ENUM ('cashapp', 'venmo', 'paypal', 'other');

CREATE TABLE donations (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  donor_email   TEXT,
  donor_name    TEXT,
  amount        DECIMAL(10,2),
  platform      donation_platform,
  reference     TEXT,
  allocated_to  TEXT DEFAULT 'general',
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Contact form submissions
CREATE TABLE contact_submissions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  email         TEXT NOT NULL,
  interest      TEXT,
  message       TEXT,
  read          BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Session requests (from service card modals)
CREATE TABLE session_requests (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT NOT NULL,
  service_type  session_type NOT NULL,
  fulfilled     BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_requests ENABLE ROW LEVEL SECURITY;

-- Patients: can read/update own row
CREATE POLICY "Patients read own" ON patients
  FOR SELECT USING (id = auth.uid());
CREATE POLICY "Patients update own" ON patients
  FOR UPDATE USING (id = auth.uid());

-- Sessions: patients see own
CREATE POLICY "Patients read own sessions" ON sessions
  FOR SELECT USING (patient_id = auth.uid());
CREATE POLICY "Patients insert own sessions" ON sessions
  FOR INSERT WITH CHECK (patient_id = auth.uid());

-- Messages: patients see own
CREATE POLICY "Patients read own messages" ON messages
  FOR SELECT USING (patient_id = auth.uid());
CREATE POLICY "Patients send messages" ON messages
  FOR INSERT WITH CHECK (patient_id = auth.uid() AND sender = 'patient');

-- Resources: visible if shared_with is empty (public) or contains patient ID
CREATE POLICY "Patients read shared resources" ON resources
  FOR SELECT USING (shared_with = '{}' OR auth.uid() = ANY(shared_with));

-- Contact submissions: public can insert
CREATE POLICY "Anyone can submit contact" ON contact_submissions
  FOR INSERT WITH CHECK (true);

-- Session requests: public can insert
CREATE POLICY "Anyone can request session" ON session_requests
  FOR INSERT WITH CHECK (true);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Generate unique 8-char access code
CREATE OR REPLACE FUNCTION generate_access_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Create patient on signup
CREATE OR REPLACE FUNCTION handle_new_patient()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO patients (id, email, full_name, access_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Patient'),
    generate_access_code()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: auto-create patient record on auth signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_patient();

-- ============================================
-- SEED DATA (demo resources)
-- ============================================

INSERT INTO resources (title, type, url, description) VALUES
  ('Grounding Techniques', 'pdf', 'https://dba.joffre-fab.workers.dev/resources/grounding.pdf', '5 simple practices for when anxiety shows up'),
  ('Understanding the Inner Critic', 'video', 'https://youtube.com/@RickeyDavid', 'David walks through where the inner critic comes from'),
  ('Guided Body Scan', 'audio', 'https://dba.joffre-fab.workers.dev/resources/body-scan.mp3', '15-minute body scan meditation for stress relief');
