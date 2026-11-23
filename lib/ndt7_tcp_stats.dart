/* Jitter and packet loss, worked out from the TCPInfo that the M-Lab server sends during a download test.
*
* NDT7 is a TCP test, so it cannot count lost packets the way a UDP test would. What it can give us:
*  - jitter: how much the round-trip time moves from one reading to the next (mean absolute difference between
*    consecutive TCPInfo.RTT readings, in ms). Falls back to the server's own RTTVar if there are too few readings.
*  - packet loss: the share of the data the server sent that it had to send again (BytesRetrans / BytesSent), as a
*    percentage. TCP re-sends lost data, so this tracks real loss on the path from the server to the phone.
* Both describe the download direction and are estimates, so they are named as such where players see them. */

class Ndt7TcpStats {
  final List<double> _rttMs = [];
  double? _rttVarMs;
  num? _bytesSent;
  num? _bytesRetrans;

  // Feed in the TCPInfo map from one server message (ignored if it is not a map).
  void addTcpInfo(dynamic tcpInfo) {
    if (tcpInfo is! Map) return;
    final rtt = tcpInfo['RTT'];
    if (rtt is num && rtt > 0) _rttMs.add(rtt / 1000.0); // reported in microseconds
    final rttVar = tcpInfo['RTTVar'];
    if (rttVar is num && rttVar >= 0) _rttVarMs = rttVar / 1000.0;
    final sent = tcpInfo['BytesSent'];
    if (sent is num) _bytesSent = sent;
    final retrans = tcpInfo['BytesRetrans'];
    if (retrans is num) _bytesRetrans = retrans;
  }

  // jitter in milliseconds, or null if the server never sent a usable round-trip time
  double? get jitterMs {
    if (_rttMs.length >= 2) {
      var total = 0.0;
      for (var i = 1; i < _rttMs.length; i++) {
        total += (_rttMs[i] - _rttMs[i - 1]).abs();
      }
      return total / (_rttMs.length - 1);
    }
    return _rttVarMs;
  }

  // estimated packet loss as a percentage (0 to 100), or null if the server sent no byte counts
  double? get packetLossPercent {
    final sent = _bytesSent;
    final retrans = _bytesRetrans;
    if (sent == null || retrans == null || sent <= 0) return null;
    return (retrans / sent * 100).clamp(0.0, 100.0).toDouble();
  }
}
