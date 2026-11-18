# VitalWatch Doctor Portal

Next.js portal where doctors sign in and manage patient review enquiries. Patient screens, habits, timelines, and demo data are not part of this app.

## Quick start

```bash
npm install
cp .env.example .env.local   # fill in the Firebase web config
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Firebase

Config is read from `NEXT_PUBLIC_FIREBASE_*` in `.env.local`.

Doctor accounts are Firebase Auth users with a Firestore profile:

```
doctors/{uid}
  name: "Dr. Anika Shah"
  email: "anika@clinic.com"
  specialty: "General medicine"
  active: true
```

Enquiries are live documents in `enquiries/{patientId}_{flagId}`, created when a patient taps **Request review** in the mobile app. Saving a response updates that enquiry and the patient's `users/{uid}/reviews/{flagId}` document.

## Scripts

- `npm run dev` — local development
- `npm run build` / `npm start` — production
- `npm run lint` — ESLint
