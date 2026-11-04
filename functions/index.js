const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { toPublicMeasurement, publicDocId } = require("./anonymize");

initializeApp();

// Keeps public_measurements in sync with every user's private collected_measurements.
// The app lets signed-in users read public_measurements (results only), never other users' own documents.
exports.publishAnonymizedMeasurement = onDocumentWritten(
  "measurements/{email}/collected_measurements/{docId}",
  async (event) => {
    const { email, docId } = event.params;
    const publicRef = getFirestore().collection("public_measurements").doc(publicDocId(email, docId));

    // measurement deleted, so remove its public copy
    if (!event.data.after.exists) {
      await publicRef.delete();
      return;
    }

    const publicData = toPublicMeasurement(event.data.after.data());
    if (publicData === null) {
      // no usable location (e.g. location services were off), so nothing to show on the map
      await publicRef.delete();
      return;
    }

    await publicRef.set({ ...publicData, updated: FieldValue.serverTimestamp() });
  }
);
