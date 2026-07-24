-- Fix: add INSERT policy for patients + make trigger SECURITY DEFINER

-- 1. Add INSERT policy so the trigger can create patient records
CREATE POLICY "Patients insert own" ON patients
  FOR INSERT WITH CHECK (id = auth.uid());

-- 2. Make the trigger function SECURITY DEFINER so it bypasses RLS
ALTER FUNCTION handle_new_patient() SECURITY DEFINER;

-- 3. Grant the function access to the auth schema
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
