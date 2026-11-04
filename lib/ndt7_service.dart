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
            'jitter': download['jitter'],
            'packetLoss': -1,
        };
    }

    // Jitter is the average change between consecutive RTT samples (as in RFC 3550), in the same unit as the samples.
    // With fewer than two samples there is nothing to compare, so it is reported as 0.
    static double calculateJitter(List<double> rttSamples) {
        if (rttSamples.length < 2) return 0.0;
        double totalDifference = 0.0;
        for (int i = 1; i < rttSamples.length; i++) {
            totalDifference += (rttSamples[i] - rttSamples[i - 1]).abs();
        }
        return totalDifference / (rttSamples.length - 1);
    }

    // Measures download speed, latency and jitter
    Future<Map<String, dynamic>> runDownloadTest(
        Function(String) onStatus) async {

        onStatus('Fetching download URL...');
        final urls = await getNDT7Urls();
        final downloadUrl = urls['download']!;

        onStatus('Connecting to: ${downloadUrl.substring(0, 50)}...');

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
        // every RTT sample (in ms) the server reports during the test, used to calculate jitter
        final List<double> rttSamples = [];
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
                        // TCPInfo.RTT (also microseconds) is the current round trip time; keep each sample
                        if (tcpInfo is Map && tcpInfo['RTT'] is num) {
                            rttSamples.add((tcpInfo['RTT'] as num) / 1000.0);
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

                // latency is the lowest RTT seen, falling back to the average if MinRTT was never reported
                final latency = minRTT ??
                    (rttSamples.isNotEmpty ? rttSamples.reduce((a, b) => a + b) / rttSamples.length : 0.0);
                final jitter = calculateJitter(rttSamples);
                onStatus('Latency: ${latency.toStringAsFixed(1)} ms, jitter: ${jitter.toStringAsFixed(2)} ms (${rttSamples.length} RTT samples)');

                completer.complete({
                    'speedMbps': speedMbps,
                    'latency': latency,
                    'jitter': jitter,
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

        onStatus('Connecting to: ${uploadUrl.substring(0, 50)}...');

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

        // NDT7 upload: client sends binary data, server sends JSON measurements
        final payload = Uint8List(8192); // 8KB chunks

        // Fill with random data (optional, but more realistic)
        for (int i = 0; i < payload.length; i++) {
        payload[i] = i % 256;
        }

        int serverMessageCount = 0;

        socket.listen(
        (message) {
        // Server sends JSON measurement messages during upload
        if (message is String) {
        serverMessageCount++;
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
        },
        );

        const testDuration = Duration(seconds: 10);

        // Send data continuously
        Timer.periodic(const Duration(milliseconds: 10), (timer) {
        if (isDone) {
        timer.cancel();
        return;
        }

        try {
        socket.add(payload);
        bytesSent += payload.length;
        chunksSent++;

        if (chunksSent % 200 == 0) {
        final mbSent = (bytesSent / 1024 / 1024).toStringAsFixed(2);
        onStatus('Sent: $mbSent MB ($chunksSent chunks)');
        }
        } catch (e) {
        onStatus('Send error: $e');
        isDone = true;
        timer.cancel();
        }

        if (DateTime.now().difference(startTime) >= testDuration) {
        isDone = true;
        timer.cancel();

        onStatus('Upload duration complete, closing...');
        socket.close();

        final durationSeconds =
        DateTime.now().difference(startTime).inMilliseconds / 1000;

        final speedMbps = (bytesSent * 8) / (durationSeconds * 1e6);

        completer.complete({
        'speedMbps': speedMbps,
        'bytesSent': bytesSent,
        'duration': durationSeconds,
        'chunksSent': chunksSent,
        });
        }
        });

        // Safety timeout
        Future.delayed(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
        onStatus('Upload timeout');
        socket.close();

        final durationSeconds =
        DateTime.now().difference(startTime).inMilliseconds / 1000;
        final speedMbps = (bytesSent * 8) / (durationSeconds * 1e6);

        completer.complete({
        'speedMbps': speedMbps,
        'bytesSent': bytesSent,
        'duration': durationSeconds,
        'chunksSent': chunksSent,
        });
        }
        });

        return completer.future;
    }
}