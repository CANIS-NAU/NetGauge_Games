> **Not in use.** This project is on the Firebase Spark plan, which cannot deploy Cloud Functions. The anonymized
> `public_measurements` copies are written by the app instead (see `lib/public_measurements.dart`). This folder is kept
> only in case the project moves to the Blaze plan later.

# NetGauge Cloud Functions

`publishAnonymizedMeasurement` copies each document in `measurements/{email}/collected_measurements`
to `public_measurements`, keeping only latitude/longitude (rounded to ~11 m), download speed, upload
speed and latency. Email, game, session ID, VPN flag and exact timestamp are never copied. The map's
"All Measurements" view reads only `public_measurements`.

## Deploy
Requires the Firebase CLI and the Blaze plan.

    cd functions && npm install
    firebase deploy --only functions

## Backfill existing measurements (once)

    gcloud auth application-default login
    cd functions && node backfill.js

## Firestore rules to add
Clients may read the anonymized collection but never write it (the function uses the admin SDK).

    match /public_measurements/{id} {
      allow read: if request.auth != null;
      allow write: if false;
    }
