# DBA — Backend Blueprint

## Stack

| Layer | Technology | Why | Cost |
|-------|-----------|-----|------|
| Database | Supabase (Postgres) | Free tier: 500MB, auth built-in, real-time | $0 |
| Auth | Supabase Auth | Email/password, magic links, OAuth | $0 |
| API | Supabase Edge Functions | Serverless, runs on Deno, colocated with DB | $0 |
| File Storage | Supabase Storage | Patient documents, resources | $0 (1GB) |
| Email | Resend / SendGrid | Transactional: session confirmations, link delivery | Free tier |
| Hosting | Cloudflare Workers | Already deployed | $0 |

**Total: $0/month** (stays within free tiers)

---

## Database Schema

### patients
```
id              uuid (PK)
email           text (unique)
full_name       text
phone           text
access_code     text (unique, 6-char)
created_at      timestamptz
last_login      timestamptz
counselor_notes text (private — counselor only)
```

### sessions
```
id              uuid (PK)
patient_id      uuid (FK → patients.id)
type            enum ('virtual', 'in-person', 'spiritual-direction')
status          enum ('requested', 'confirmed', 'completed', 'cancelled')
scheduled_at    timestamptz
duration_min    int (default 50)
meeting_link    text         -- virtual session URL
location        text         -- for in-person
notes           text
created_at      timestamptz
```

### messages
```
id              uuid (PK)
patient_id      uuid (FK → patients.id)
sender          enum ('patient', 'counselor')
content         text
read            bool (default false)
created_at      timestamptz
```

### resources
```
id              uuid (PK)
title           text
type            enum ('pdf', 'video', 'audio', 'link')
url             text          -- storage URL or external link
description     text
shared_with     uuid[]        -- array of patient IDs (empty = all)
created_at      timestamptz
```

### donations
```
id              uuid (PK)
donor_email     text
donor_name      text
amount          decimal
platform        enum ('cashapp', 'venmo', 'paypal', 'other')
reference       text          -- transaction ID or confirmation
allocated_to    text          -- 'general', 'food', 'kids', 'supplies'
created_at      timestamptz
```

### contact_submissions
```
id              uuid (PK)
name            text
email           text
interest        text          -- from dropdown
message         text
created_at      timestamptz
read            bool (default false)
```

### session_requests
```
id              uuid (PK)
email           text
service_type    enum ('virtual', 'in-person', 'spiritual-direction')
created_at      timestamptz
fulfilled       bool (default false)
```

---

## API Endpoints

### Auth
```
POST   /api/auth/signup          — Create patient account (email + access_code)
POST   /api/auth/login           — Login with email + access_code
POST   /api/auth/magic-link      — Send magic link email
GET    /api/auth/me              — Get current user session
```

### Portal (authenticated)
```
GET    /api/portal/sessions      — Patient's sessions
POST   /api/portal/sessions      — Create new session request
PATCH  /api/portal/sessions/:id  — Reschedule/cancel
GET    /api/portal/messages      — Patient's messages
POST   /api/portal/messages      — Send message to counselor
GET    /api/portal/resources     — Available resources
```

### Public Forms
```
POST   /api/contact              — Contact form submission → email David
POST   /api/request-session      — Session request from service card modal → email David
POST   /api/donate               — Log donation (webhook from Cash App/Venmo/PayPal)
```

### Admin (counselor only)
```
GET    /api/admin/patients       — List all patients
GET    /api/admin/sessions       — All sessions (filterable)
PATCH  /api/admin/sessions/:id   — Confirm/cancel/complete session
POST   /api/admin/messages       — Send message to patient
POST   /api/admin/resources      — Upload/share resource
GET    /api/admin/donations      — Donation log
GET    /api/admin/contacts       — Contact form submissions
```

---

## Portal Integration Plan

### Current → Target

| Feature | Current (Client-side) | Target (Backend) |
|---------|----------------------|------------------|
| Login | Any 6-char code → localStorage | Email + access_code → Supabase Auth |
| Sessions | Hardcoded demo data | Real DB, patient-specific |
| Messages | Hardcoded demo data | Real DB, counselor can send |
| Resources | Hardcoded demo data | Real DB, uploadable |
| Profile | Static | Editable, persisted |
| Session modal | JS alert simulation | POST to API → emails David |

---

## Email Automations

| Trigger | Email | To |
|---------|-------|----|
| Session request submitted | "David, new session request from {email} — {type}" | david@dba.org |
| Session confirmed | "Your {type} session is confirmed for {date}" | patient |
| Session reminder (24h) | "Reminder: session tomorrow at {time}" | patient |
| Contact form submitted | "New contact from {name} — {message}" | david@dba.org |
| New patient signup | "Welcome to DBA, {name}. Your access code: {code}" | patient |
| Resource shared | "David shared a new resource: {title}" | patient |

---

## Security Rules (Supabase RLS)

```sql
-- Patients can only see their own data
patients:    SELECT (auth.uid() = id)
sessions:    SELECT (patient_id = auth.uid())
messages:    SELECT (patient_id = auth.uid())
resources:   SELECT (auth.uid() = ANY(shared_with) OR shared_with = '{}')

-- Patients can insert their own data
sessions:    INSERT (patient_id = auth.uid())
messages:    INSERT (patient_id = auth.uid() AND sender = 'patient')

-- Counselor (admin role) can see/modify all
-- Controlled by Supabase custom claims: { role: 'counselor' }
```

---

## Implementation Phases

### Phase 1 — Core (today)
- [ ] Supabase project setup
- [ ] Database schema created
- [ ] Auth flow: signup + login with magic link
- [ ] Portal connected to real backend (replace localStorage)
- [ ] Contact form → Supabase (replaces Netlify Forms)

### Phase 2 — Sessions + Messaging
- [ ] Session request flow: modal → API → DB → email David
- [ ] Patient dashboard: real sessions from DB
- [ ] Messaging: patient ↔ counselor

### Phase 3 — Admin + Donations
- [ ] Counselor admin panel (manage sessions, patients, messages)
- [ ] Donation tracking
- [ ] Resource upload/sharing

### Phase 4 — Polish
- [ ] Email automations (Resend/SendGrid)
- [ ] Session reminders
- [ ] Analytics dashboard
