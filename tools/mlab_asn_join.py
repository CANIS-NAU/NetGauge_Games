#!/usr/bin/env python3
"""Adds the internet provider (ASN and name) to exported NetGauge measurements, using M-Lab's public data.

How it works: each measurement stores M-Lab's test IDs in its `mlab` field. M-Lab publishes every NDT7 test in
BigQuery (measurement-lab.ndt.ndt7) with the client's network annotation. This script looks the IDs up there and
writes the provider next to each measurement. No client IP address is ever stored by the app or needed here.

Usage:
  pip install google-cloud-bigquery
  gcloud auth application-default login     # any Google account can query M-Lab's public data
  python3 tools/mlab_asn_join.py measurements.json joined.json

Input: a JSON list of measurement records (a Firestore export). Each needs `mlab.download_uuid` and/or `mlab.upload_uuid`.
M-Lab adds tests a day or more after they happen, so records younger than that may stay unmatched: run again later.

CHECK BEFORE RELYING ON IT: the table and field names below follow M-Lab's documented ndt7 schema as I know it
(a.UUID, client.Network.ASNumber, client.Network.ASName, date). Confirm them against
https://www.measurementlab.net/data/ and adjust QUERY if the schema has changed.
"""
import json
import sys

QUERY = """
SELECT a.UUID AS uuid,
       client.Network.ASNumber AS asn,
       client.Network.ASName AS asn_name
FROM `measurement-lab.ndt.ndt7`
WHERE date BETWEEN @start AND @end
  AND a.UUID IN UNNEST(@uuids)
"""


def uuids_of(record):
    mlab = record.get("mlab") or {}
    return [u for u in (mlab.get("download_uuid"), mlab.get("upload_uuid")) if u]


def main(src, dst):
    from google.cloud import bigquery

    with open(src) as f:
        records = json.load(f)
    ids = sorted({u for r in records for u in uuids_of(r)})
    if not ids:
        sys.exit("No M-Lab UUIDs in the input.")

    # limit the scan to the dates involved (the table is partitioned by date; a wide scan is costly)
    dates = sorted(str(r.get("date") or r.get("timestamp", ""))[:10] for r in records if r.get("date") or r.get("timestamp"))
    if not dates:
        sys.exit("Records need a `date` or `timestamp` (YYYY-MM-DD...) so the query can be date-limited.")
    client = bigquery.Client()
    job = client.query(QUERY, job_config=bigquery.QueryJobConfig(query_parameters=[
        bigquery.ScalarQueryParameter("start", "DATE", dates[0]),
        bigquery.ScalarQueryParameter("end", "DATE", dates[-1]),
        bigquery.ArrayQueryParameter("uuids", "STRING", ids),
    ]))
    found = {row.uuid: {"asn": row.asn, "asn_name": row.asn_name} for row in job.result()}

    matched = 0
    for r in records:
        hit = next((found[u] for u in uuids_of(r) if u in found), None)
        r["provider"] = hit  # None = not in M-Lab's data yet (or never was)
        matched += hit is not None
    with open(dst, "w") as f:
        json.dump(records, f, indent=2)
    print(f"{matched} of {len(records)} records matched; wrote {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
