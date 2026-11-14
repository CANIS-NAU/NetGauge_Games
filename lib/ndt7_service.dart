import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';


class NDT7Service {
    // time of last request
    DateTime? _lastRequestTime;
    Map<String, String>? _cachedUrls;


    // get URLs for speed test
    Future<Map<String, String>> getNDT7Urls() async {
      if (_cachedUrls != null) {
        debugPrint('[NDT7] Using cached URLs');
        return _cachedUrls!;
      }

      final response = await http.get(
        Uri.parse('https://locate.measurementlab.net/v2/nearest/ndt/ndt7'),
      );

      if (response.statusCode != 200) {
        throw Exception('Locate API failed with status ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final Map<String, dynamic> urls = data['results'][0]['urls'];
      String downloadUrl = urls['ws:///ndt/v7/download'];
      String uploadUrl = urls['ws:///ndt/v7/upload'];

      downloadUrl = downloadUrl.replaceFirst('ws://', 'wss://');
      uploadUrl = uploadUrl.replaceFirst('ws://', 'wss://');

      _cachedUrls = {'download': downloadUrl, 'upload': uploadUrl};
      return _cachedUrls!;
    }

    // Function to run a full network test (dl speed, ul speed, round trip time)
    Future<Map<String, dynamic>> runFullTest() async {
        final urls = await getNDT7Urls();

        // Run download test without callback
        final download = await runDownloadTest((status) {
            // Just print to console, no UI updates
            print('[NDT71] $status');
        });

        // Run upload test without callback
        final upload = await runUploadTest((status) {
            print('[NDT72] $status');
        });

        return {
            'downloadSpeed': download['speedMbps'],
            'uploadSpeed': upload['speedMbps'],
            'latency': download['latency'],
            'jitter': -1,
            'packetLoss': -1,
        };
    }

    // Measures download speed
    Future<Map<String, dynamic>> runDownloadTest(
        Function(String) onStatus) async {

        onStatus('Fetching download URL...');
        final urls = await getNDT7Urls();
        final downloadUrl = urls['download']!;

        onStatus('Connecting to download server...');

        final socket = await WebSocket.connect(
            downloadUrl,
            protocols: ['net.measurementlab.ndt.v7'],
        );

        onStatus('WebSocket connected! State: ${socket.readyState}');

        final startTime = DateTime.now();
        int bytesReceived = 0;
        int jsonMessageCount = 0;
        int binaryMessageCount = 0;
        double? minRTT;
        bool testStarted = false;

        final completer = Completer<Map<String, dynamic>>();

        socket.listen(
                (message) {
                if (!testStarted) {
                    testStarted = true;
                    onStatus('First message received! Test started.');
                }

                if (message is String) {
                    // JSON measurement messages
                    jsonMessageCount++;

                    try {
                        final data = jsonDecode(message);

                        // NDT7 sends different message types
                        if (data.containsKey('AppInfo') && data['AppInfo'] != null) {
                            if (data['AppInfo']['NumBytes'] != null) {
                                bytesReceived = data['AppInfo']['NumBytes'];
                            }
                        }

                        // TCPInfo.MinRTT is reported in microseconds; convert to milliseconds for latency
                        // (ConnectionInfo.Client is just an address string, so it holds no RTT)
                        final tcpInfo = data['TCPInfo'];
                        if (tcpInfo is Map && tcpInfo['MinRTT'] is num) {
                            minRTT = (tcpInfo['MinRTT'] as num) / 1000.0;
                        }

                        if (jsonMessageCount % 10 == 0) {
                            final mbReceived = (bytesReceived / 1024 / 1024).toStringAsFixed(2);
                            onStatus('JSON msgs: $jsonMessageCount, Data: $mbReceived MB');
                        }
                    } catch (e) {
                        onStatus('JSON parse error: $e');
                    }
                } else if (message is List<int>) {
                    // Binary data from server
                    binaryMessageCount++;
                    bytesReceived += message.length;

                    if (binaryMessageCount % 200 == 0) {
                        final mbReceived = (bytesReceived / 1024 / 1024).toStringAsFixed(2);
                        onStatus('Binary msgs: $binaryMessageCount, Total: $mbReceived MB');
                    }
                }
            },
            onDone: () {
                final endTime = DateTime.now();
                final durationSeconds =
                    endTime.difference(startTime).inMilliseconds / 1000;

                debugPrint('[DOWNLOAD] Test completed:');
                debugPrint('[DOWNLOAD] - Duration: $durationSeconds seconds');
                debugPrint('[DOWNLOAD] - Bytes received: $bytesReceived');
                debugPrint('[DOWNLOAD] - JSON messages: $jsonMessageCount');
                debugPrint('[DOWNLOAD] - Binary messages: $binaryMessageCount');
                debugPrint('[DOWNLOAD] - Test started flag: $testStarted');

                onStatus('Connection closed after $durationSeconds sec');

                onStatus('Connection closed after $durationSeconds sec');
                onStatus('Total: $bytesReceived bytes, $jsonMessageCount JSON, $binaryMessageCount binary');

                if (!testStarted) {
                    onStatus('WARNING: No data received!');
                }

                final speedMbps = durationSeconds > 0
                    ? (bytesReceived * 8) / (durationSeconds * 1e6)
                    : 0.0;

                completer.complete({
                    'speedMbps': speedMbps,
                    'latency': minRTT ?? 0,
                    'bytesReceived': bytesReceived,
                    'duration': durationSeconds,
                    'messageCount': jsonMessageCount + binaryMessageCount,
                });
            },
            onError: (error) {
                onStatus('ERROR: $error');
                if (!completer.isCompleted) {
                    completer.completeError(error);
                }
            },
        );

        // NDT7 download test typically runs for 10 seconds
        Future.delayed(const Duration(seconds: 12), () {
            if (!completer.isCompleted) {
                onStatus('Timeout - closing connection');
                socket.close();
            }
        });

        return completer.future;
    }

    Future<Map<String, dynamic>> runUploadTest(
        Function(String) onStatus) async {

        onStatus('Fetching upload URL...');
        final urls = await getNDT7Urls();
        final uploadUrl = urls['upload']!;

        onStatus('Connecting to upload server...');

        final socket = await WebSocket.connect(
            uploadUrl,
            protocols: ['net.measurementlab.ndt.v7'],
        );

        onStatus('WebSocket connected!');

        final startTime = DateTime.now();
        final completer = Completer<Map<String, dynamic>>();

        int bytesSent = 0;
        int chunksSent = 0;
        bool isDone = false;
        // what the server says it has received, which is what the upload speed is really measured from
        int serverBytes = 0;
        double serverElapsedSeconds = 0;
        int serverMessageCount = 0;

        // 64 KB frames, sent as fast as the connection takes them (the old 8 KB every 10 ms capped the test at 6.5 Mbps)
        final payload = Uint8List(64 * 1024);
        for (int i = 0; i < payload.length; i++) {
            payload[i] = i % 256;
        }
        // how far ahead of the server the client may get before it waits, so a slow link does not buffer without limit
        const maxLead = 4 * 1024 * 1024;

        void finish() {
            if (completer.isCompleted) return;
            isDone = true;
            socket.close();
            final durationSeconds = DateTime.now().difference(startTime).inMilliseconds / 1000;
            // prefer the server's own count and clock; fall back to what was handed to the socket
            final speedMbps = (serverBytes > 0 && serverElapsedSeconds > 0)
                ? (serverBytes * 8) / (serverElapsedSeconds * 1e6)
                : (durationSeconds > 0 ? (bytesSent * 8) / (durationSeconds * 1e6) : 0.0);
            completer.complete({
                'speedMbps': speedMbps,
                'bytesSent': bytesSent,
                'duration': durationSeconds,
                'chunksSent': chunksSent,
            });
        }

        socket.listen(
            (message) {
                if (message is String) {
                    serverMessageCount++;
                    try {
                        final data = jsonDecode(message);
                        final app = data is Map ? data['AppInfo'] : null;
                        if (app is Map && app['NumBytes'] is num && app['ElapsedTime'] is num) {
                            serverBytes = (app['NumBytes'] as num).toInt();
                            // ElapsedTime is in microseconds
                            serverElapsedSeconds = (app['ElapsedTime'] as num) / 1e6;
                        }
                    } catch (_) {}
                    if (serverMessageCount % 5 == 0) {
                        onStatus('Server measurement msgs: $serverMessageCount');
                    }
                }
            },
            onError: (error) {
                onStatus('Upload error: $error');
                if (!completer.isCompleted) {
                    completer.completeError(error);
                }
            },
            onDone: () {
                onStatus('Upload socket closed by server');
                // the server ends the test itself; report what was measured rather than waiting for the safety timer
                if (!isDone) finish();
            },
        );

        const testDuration = Duration(seconds: 10);

        () async {
            while (!isDone && DateTime.now().difference(startTime) < testDuration) {
                final waiting = serverMessageCount == 0 ? bytesSent > 1024 * 1024 : bytesSent - serverBytes > maxLead;
                if (waiting) {
                    await Future.delayed(const Duration(milliseconds: 5));
                    continue;
                }
                try {
                    socket.add(payload);
                    bytesSent += payload.length;
                    chunksSent++;
                } catch (e) {
                    onStatus('Send error: $e');
                    break;
                }
                // let the socket and the listener run between frames
                await Future.delayed(Duration.zero);
            }
            finish();
        }();

        // Safety timeout
        Future.delayed(const Duration(seconds: 15), () {
            if (!completer.isCompleted) {
                onStatus('Upload timeout');
                finish();
            }
        });

        return completer.future;
    }
}
