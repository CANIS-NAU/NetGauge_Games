/* Identifiers that tie one of our speed tests to M-Lab's own public record of it.
*
* Every NDT7 test has a UUID that the M-Lab server assigns and reports in its JSON messages. M-Lab publishes
* each test (and later adds the client's ISP / ASN) in its open BigQuery data, so storing the UUID lets that
* provider information be joined on offline (see tools/mlab_asn_join.py).
*
* Deliberately NOT stored: the client IP address. The UUID is enough to find the test again. */

class MlabTestInfo {
  // one UUID per connection: the download and the upload are separate NDT7 tests
  final String? downloadUuid;
  final String? uploadUuid;
  // the M-Lab server that ran the test (hostname) and where it is
  final String? server;
  final String? serverCity;
  final String? serverCountry;

  const MlabTestInfo({
    this.downloadUuid,
    this.uploadUuid,
    this.server,
    this.serverCity,
    this.serverCountry,
  });

  // the UUID from one NDT7 server message (already JSON-decoded), or null if it has none
  static String? uuidFromMessage(dynamic message) {
    if (message is! Map) return null;
    final info = message['ConnectionInfo'];
    if (info is! Map) return null;
    final uuid = info['UUID'];
    return uuid is String && uuid.isNotEmpty ? uuid : null;
  }

  // the server details from the locate API response (the first result is the server we use)
  static MlabTestInfo serverFromLocate(dynamic locateResult) {
    if (locateResult is! Map) return const MlabTestInfo();
    final location = locateResult['location'];
    String? str(dynamic v) => v is String && v.isNotEmpty ? v : null;
    return MlabTestInfo(
      server: str(locateResult['machine']),
      serverCity: location is Map ? str(location['city']) : null,
      serverCountry: location is Map ? str(location['country']) : null,
    );
  }

  // combines the server details with the UUIDs the two tests reported
  MlabTestInfo withUuids({String? download, String? upload}) => MlabTestInfo(
        downloadUuid: download,
        uploadUuid: upload,
        server: server,
        serverCity: serverCity,
        serverCountry: serverCountry,
      );

  // true when there is nothing worth storing
  bool get isEmpty =>
      downloadUuid == null && uploadUuid == null && server == null;

  // the `mlab` field saved with a measurement; null values are kept so "could not capture" is visible
  Map<String, dynamic> toMeasurementField() => {
        'download_uuid': downloadUuid,
        'upload_uuid': uploadUuid,
        'server': server,
        'server_city': serverCity,
        'server_country': serverCountry,
      };
}
