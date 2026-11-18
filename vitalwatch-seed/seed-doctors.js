// Seed doctor Auth users + Firestore `doctors/{uid}` profiles for the doctor portal.
// Usage: node seed-doctors.js
// Needs ./serviceAccountKey.json (keep it out of git).

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

initializeApp({ credential: cert(require('./serviceAccountKey.json')) });
const db = getFirestore();
const auth = getAuth();

const DOCTOR_PASSWORD = 'Doctor@12345';

const DOCTORS = [
  {
    uid: 'doctor_anika',
    email: 'anika@demo.vitalwatch.app',
    name: 'Dr. Anika Shah',
    specialty: 'General medicine',
  },
  {
    uid: 'doctor_vikram',
    email: 'vikram@demo.vitalwatch.app',
    name: 'Dr. Vikram Mehta',
    specialty: 'Cardiology',
  },
  {
    uid: 'doctor_priya',
    email: 'priya@demo.vitalwatch.app',
    name: 'Dr. Priya Nair',
    specialty: 'Sleep medicine',
  },
];

async function ensureAuthUser(doctor) {
  const base = {
    email: doctor.email,
    password: DOCTOR_PASSWORD,
    displayName: doctor.name,
    emailVerified: true,
  };
  try {
    await auth.updateUser(doctor.uid, base);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      await auth.createUser({ uid: doctor.uid, ...base });
    } else if (error.code === 'auth/email-already-exists') {
      const existing = await auth.getUserByEmail(doctor.email);
      console.log(
        `  note: ${doctor.email} already exists as ${existing.uid}; writing doctors/${existing.uid}`
      );
      doctor.uid = existing.uid;
      await auth.updateUser(existing.uid, {
        password: DOCTOR_PASSWORD,
        displayName: doctor.name,
        emailVerified: true,
      });
    } else {
      throw error;
    }
  }
}

async function main() {
  console.log('Seeding doctors…\n');

  for (const doctor of DOCTORS) {
    await ensureAuthUser(doctor);
    await db.doc(`doctors/${doctor.uid}`).set(
      {
        name: doctor.name,
        email: doctor.email,
        specialty: doctor.specialty,
        active: true,
        seeded: true,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log(`  doctors/${doctor.uid}  ${doctor.name}`);
  }

  console.log('\nDoctor logins (password: ' + DOCTOR_PASSWORD + ')');
  DOCTORS.forEach((doctor) => console.log(' ', doctor.email));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
