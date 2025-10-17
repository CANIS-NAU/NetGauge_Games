import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

class NDT7Service {

    // URLs for download and upload speed measurements
    static const _downloadUrl = 'wss://ndt7.mlab-oti.measurementlab.net/ndt/v7/download';
    static const _uploadUrl = 'wss://ndt7.mlab-oti.measurementlab.net/ndt/v7/upload';

    // Function to run a full network test (dl speed, ul speed, round trip time)
    static Future<Map<String, dynamic>> runFullTest() async {

        // run functions to get Download and Upload speeds
        final download = await _runDownloadTest();
        final upload = await _runUploadTest();

        // Rough latency estimation based on RTT for WebSocket setup
        final latency = download['latency'] ?? -1; // Default to -1 if latency can't be collected

        // extract information and return
        return {
            'uploadSpeed': upload['speedMbps'],
            'downloadSpeed': download['speedMbps'],
            'latency': latency,
            'jitter': -1, // placeholder for future implementation
            'packetLoss': -1, // placeholder for future implementation
        };
    }

    // Measures download speed
    static Future<Map<String, dynamic>> _runDownloadTest() async {
        final channel = WebSocketChannel.connect(Uri.parse(_downloadUrl));
        final completer = Completer<Map<String, dynamic>>();

        int totalBytes = 0;
        final startTime = DateTime.now();
        late DateTime endTime;

        channel.stream.listen((event) {
            if (event is String) {
                // Control message, ignore for now
            } else if (event is List<int>) {
                totalBytes += event.length;
                endTime = DateTime.now();
            }
        },

        onDone: () {
            final duration = endTime.difference(startTime).inMilliseconds / 1000.0;
            final speedMbps = (totalBytes * 8) / (duration * 1000000);
            completer.complete({
                'speedMbps': speedMbps,
                'latency' : endTime.difference(startTime).inMilliseconds.toDouble();
            });
        },

        onError: (err) => completer.completeError(err));

        return completer.future;
    }

    // Measures upload speed
    static Future<Map<String, dynamic>> _runUploadTest() async {
        final channel = WebSocketChannel.connect(Uri.parse(_uploadUrl));
        final completer = Completer<Map<String, dynamic>>();

        final payload = List<int>.filled(8192, 1); // 8 KB chunks
        int sentBytes = 0;
        final startTime = DateTime.now();
        final timer = Timer.periodic(Duration(milliseconds: 100), (t) {
            channel.sink.add(payload);
            sentBytes += payload.length;
            if (DateTime.now().difference(startTime).inSeconds >= 10) {
                t.cancel();
                channel.sink.close();
            }
        });

        channel.stream.listen((event) {
            // Optional: parse server response
        },
        
        onDone: () {
            final duration = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
            final speedMbps = (sentBytes * 8) / (duration * 1000000);
            completer.complete({'speedMbps': speedMbps});
        },

        onError: (err) => completer.completeError(err));

        return completer.future;
    }
}
