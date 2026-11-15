import 'package:flutter_test/flutter_test.dart';
import 'package:internet_measurement_games_app/ndt7_tcp_stats.dart';

void main() {
  test('jitter is the average change between consecutive round-trip times, in ms', () {
    final s = Ndt7TcpStats();
    // 20 ms, 25 ms, 22 ms, 30 ms (reported in microseconds): changes of 5, 3 and 8
    for (final rtt in [20000, 25000, 22000, 30000]) {
      s.addTcpInfo({'RTT': rtt});
    }
    expect(s.jitterMs, closeTo((5 + 3 + 8) / 3, 1e-9));
  });

  test('a steady connection has zero jitter', () {
    final s = Ndt7TcpStats()
      ..addTcpInfo({'RTT': 15000})
      ..addTcpInfo({'RTT': 15000});
    expect(s.jitterMs, 0);
  });

  test('with only one reading, jitter falls back to RTTVar', () {
    final s = Ndt7TcpStats()..addTcpInfo({'RTT': 20000, 'RTTVar': 4000});
    expect(s.jitterMs, 4);
  });

  test('jitter is null when the server sent nothing usable', () {
    final s = Ndt7TcpStats()
      ..addTcpInfo(null)
      ..addTcpInfo('text')
      ..addTcpInfo({'RTT': 0})
      ..addTcpInfo({'MinRTT': 9000});
    expect(s.jitterMs, isNull);
    expect(s.packetLossPercent, isNull);
  });

  test('packet loss is the re-sent share of sent bytes, using the latest counts', () {
    final s = Ndt7TcpStats()
      ..addTcpInfo({'BytesSent': 1000, 'BytesRetrans': 0})
      ..addTcpInfo({'BytesSent': 2000000, 'BytesRetrans': 5000});
    expect(s.packetLossPercent, closeTo(0.25, 1e-9));
  });

  test('packet loss is 0 when nothing was re-sent, and null when no bytes were sent', () {
    expect((Ndt7TcpStats()..addTcpInfo({'BytesSent': 500, 'BytesRetrans': 0})).packetLossPercent, 0);
    expect((Ndt7TcpStats()..addTcpInfo({'BytesSent': 0, 'BytesRetrans': 0})).packetLossPercent, isNull);
  });

  test('packet loss never goes above 100%', () {
    final s = Ndt7TcpStats()..addTcpInfo({'BytesSent': 10, 'BytesRetrans': 50});
    expect(s.packetLossPercent, 100);
  });
}
