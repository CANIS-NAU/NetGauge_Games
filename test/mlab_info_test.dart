import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/mlab_info.dart';

void main() {
  test('reads the UUID from a server message', () {
    expect(MlabTestInfo.uuidFromMessage({'ConnectionInfo': {'Client': 'x', 'UUID': 'abc-123'}}), 'abc-123');
  });

  test('returns null when there is no usable UUID', () {
    expect(MlabTestInfo.uuidFromMessage({'AppInfo': {}}), isNull);
    expect(MlabTestInfo.uuidFromMessage({'ConnectionInfo': {'UUID': ''}}), isNull);
    expect(MlabTestInfo.uuidFromMessage({'ConnectionInfo': {'UUID': 5}}), isNull);
    expect(MlabTestInfo.uuidFromMessage('text'), isNull);
    expect(MlabTestInfo.uuidFromMessage(null), isNull);
  });

  test('reads the server from a locate result', () {
    final info = MlabTestInfo.serverFromLocate({
      'machine': 'mlab1-lax01.mlab-oti.measurement-lab.org',
      'location': {'city': 'Los Angeles', 'country': 'US'},
    });
    expect(info.server, startsWith('mlab1-lax01'));
    expect(info.serverCity, 'Los Angeles');
    expect(info.serverCountry, 'US');
    expect(MlabTestInfo.serverFromLocate(null).isEmpty, isTrue);
  });

  test('measurement field holds both UUIDs, the server, and never an IP', () {
    final field = const MlabTestInfo(server: 's', serverCity: 'c', serverCountry: 'US')
        .withUuids(download: 'd1', upload: 'u1')
        .toMeasurementField();
    expect(field, {
      'download_uuid': 'd1',
      'upload_uuid': 'u1',
      'server': 's',
      'server_city': 'c',
      'server_country': 'US',
    });
    expect(field.keys.any((k) => k.contains('ip')), isFalse);
  });
}
