// One-time script that copies existing measurements into public_measurements.
// Run from this folder with Application Default Credentials for the project:
//   gcloud auth application-default login
//   npm install && node backfill.js
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { toPublicMeasurement, publicDocId } = require("./anonymize");

initializeApp({ projectId: "nauimg-524b6" });

async function main() {
  const db = getFirestore();
  const snapshot = await db.collectionGroup("collected_measurements").get();
  let writer = db.bulkWriter();
  let copied = 0;

  for (const doc of snapshot.docs) {
    // path is measurements/{email}/collected_measurements/{docId}
    const email = doc.ref.parent.parent.id;
    const publicData = toPublicMeasurement(doc.data());
    if (publicData === null) continue;
    writer.set(db.collection("public_measurements").doc(publicDocId(email, doc.id)), {
      ...publicData,
      updated: FieldValue.serverTimestamp(),
    });
    copied++;
  }

  await writer.close();
  console.log(`Copied ${copied} of ${snapshot.size} measurements.`);
}

main().catch((e) => { console.error(e); process.exit(1); });
