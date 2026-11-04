const crypto = require("crypto");

// Builds the public, anonymized copy of a measurement, or returns null if it cannot be shown on a map.
// Only the measurement results and a coarsened location are kept. The user's email, the game played,
// the session ID, VPN status and the exact timestamp are all dropped.
function toPublicMeasurement(data) {
  const isNum = (v) => typeof v === "number" && Number.isFinite(v);
  if (!isNum(data.latitude) || !isNum(data.longitude)) return null;

  // 4 decimal places is roughly 11 m, enough for a heat map without pinpointing a doorstep
  const round = (v) => Math.round(v * 1e4) / 1e4;

  return {
    latitude: round(data.latitude),
    longitude: round(data.longitude),
    download_speed: isNum(data.download_speed) ? data.download_speed : 0,
    upload_speed: isNum(data.upload_speed) ? data.upload_speed : 0,
    latency: isNum(data.latency) ? data.latency : 0,
  };
}

// The public document ID is a hash of the owner and source document, so it cannot be traced back to either.
function publicDocId(email, docId) {
  return crypto.createHash("sha256").update(`${email}/${docId}`).digest("hex");
}

module.exports = { toPublicMeasurement, publicDocId };
