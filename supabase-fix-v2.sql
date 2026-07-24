-- V2: Clean trigger — drop and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_patient();

-- Recreate as SECURITY DEFINER from the start
CREATE OR REPLACE FUNCTION handle_new_patient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.patients (id, email, full_name, access_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', 'Patient'),
    public.generate_access_code()
  );
  RETURN NEW;
END;
$$;

-- Recreate trigger  
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_patient();

-- Ensure the patients table has INSERT permission via RLS
DROP POLICY IF EXISTS "Patients insert own" ON patients;
CREATE POLICY "Patients insert own" ON patients
  FOR INSERT WITH CHECK (true);
