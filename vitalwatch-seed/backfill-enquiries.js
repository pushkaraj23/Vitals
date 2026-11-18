// Backfill portal enquiries from pending patient reviews that never reached
// the enquiries collection (partial write failure).
// Usage: node backfill-enquiries.js

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp({ credential: cert(require('./serviceAccountKey.json')) });
const db = getFirestore();

async function main() {
  const users = await db.collection('users').get();
  let created = 0;
  let skipped = 0;

  for (const userDoc of users.docs) {
    const uid = userDoc.id;
    const user = userDoc.data() || {};
    const reviews = await userDoc.ref.collection('reviews').get();

    for (const reviewDoc of reviews.docs) {
      const flagId = reviewDoc.id;
      const review = reviewDoc.data() || {};
      const status = review.status;
      const simulated = review.simulated === true;

      if (simulated) {
        skipped += 1;
        continue;
      }
      if (status !== 'pending' && status !== 'in_review') {
        // Still backfill reviewed ones only if enquiry missing? Skip completed.
        if (status === 'reviewed') {
          skipped += 1;
          continue;
        }
        // Legacy pending docs without status but reviewer Pending*
        if (
          status != null ||
          !(
            review.reviewerName === 'Pending' ||
            review.reviewerName === 'Pending clinician assignment'
          )
        ) {
          skipped += 1;
          continue;
        }
      }

      const enquiryId = `${uid}_${flagId}`;
      const enquiryRef = db.collection('enquiries').doc(enquiryId);
      const existing = await enquiryRef.get();
      if (existing.exists) {
        skipped += 1;
        continue;
      }

      let flagTitle = 'Pattern flag';
      let flagLevel = '';
      let metric = '';
      const flagSnap = await userDoc.ref.collection('flags').doc(flagId).get();
      if (flagSnap.exists) {
        const flag = flagSnap.data() || {};
        flagTitle = flag.title || flagTitle;
        flagLevel = flag.level || '';
        metric = flag.metric || '';
      }

      await enquiryRef.set({
        patientId: uid,
        patientName: user.name || 'Patient',
        patientEmail: user.email || null,
        flagId,
        flagTitle,
        flagLevel,
        metric,
        message:
          review.note ||
          'Patient requested a doctor review of this pattern.',
        status: status === 'in_review' ? 'in_review' : 'open',
        verdict: null,
        doctorNote: '',
        doctorId: null,
        doctorName: null,
        createdAt: review.requestedAt || FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        backfilled: true,
      });

      created += 1;
      console.log(`  created enquiries/${enquiryId}`);
    }
  }

  console.log(`\nDone. created=${created} skipped=${skipped}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
