import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';


class NDT7Service {
    // URLs for download and upload speed measurements

    // get URLs for speed test
    Future<Map<String, String>> getNDT7Urls() async {
        final response = await http.get(
            Uri.parse('https://locate.measurementlab.net/v2/nearest/ndt/ndt7'),
        );

        if (response.statusCode != 200) {
            throw Exception('Locate API failed with status ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final urls = data['results'][0]['urls'];

        String downloadUrl = urls['ws:///ndt/v7/download'];
        String uploadUrl = urls['ws:///ndt/v7/upload'];

        // Force secure WebSocket for iOS production
        downloadUrl = downloadUrl.replaceFirst('ws://', 'wss://');
        uploadUrl = uploadUrl.replaceFirst('ws://', 'wss://');

        debugPrint('[NDT7] Download URL (secure): $downloadUrl');
        debugPrint('[NDT7] Upload URL (secure): $uploadUrl');

        return {
            'download': downloadUrl,
            'upload': uploadUrl,
        };
    }

    // Function to run a full network test (dl speed, ul speed, round trip time)
    Future<Map<String, dynamic>> runFullTest() async {
        final urls = await getNDT7Urls();

        final download = await _runDownloadTest(urls['download']!);
        final upload = await _runUploadTest(urls['upload']!);

        return {
            'downloadSpeed': download['speedMbps'],
            'uploadSpeed': upload['speedMbps'],
            'latency': download['latency'],
            'jitter': -1,
            'packetLoss': -1,
        };
    }

    // Measures download speed
    Future<Map<String, dynamic>> _runDownloadTest(String downloadUrl) async {
        final uri = Uri.parse(downloadUrl);
        final socket = await WebSocket.connect(
            downloadUrl,
            protocols: ['net.measurementlab.ndt.v7'],
        );

        final startTime = DateTime.now();
        int bytesReceived = 0;

        final completer = Completer<Map<String, dynamic>>();

        socket.listen(
                (message) {
                if (message is String) {
                    final data = jsonDecode(message);

                    if (data['AppInfo']?['NumBytes'] != null) {
                        bytesReceived = data['AppInfo']['NumBytes'];
                    }
                }
            },
            onDone: () {
                final endTime = DateTime.now();
                final durationSeconds =
                    endTime.difference(startTime).inMilliseconds / 1000;

                final speedMbps = (bytesReceived * 8) / (durationSeconds * 1e6);

                completer.complete({
                    'speedMbps': speedMbps,
                    'latency': 0,
                });
            },
            onError: (error) {
                if (!completer.isCompleted) {
                    completer.completeError(error);
                }
            },
        );

        return completer.future;
    }

    Future<Map<String, dynamic>> _runUploadTest(String uploadUrl) async {
        final uri = Uri.parse(uploadUrl);
        final socket = await WebSocket.connect(
            uploadUrl,
            protocols: ['net.measurementlab.ndt.v7'],
        );

        final startTime = DateTime.now();
        int bytesReceived = 0;

        final completer = Completer<Map<String, dynamic>>();

        socket.listen(
                (message) {
                if (message is String) {
                    final data = jsonDecode(message);

                    if (data['AppInfo']?['NumBytes'] != null) {
                        bytesReceived = data['AppInfo']['NumBytes'];
                    }
                }
            },
            onDone: () {
                final endTime = DateTime.now();
                final durationSeconds =
                    endTime.difference(startTime).inMilliseconds / 1000;

                final speedMbps = (bytesReceived * 8) / (durationSeconds * 1e6);

                completer.complete({
                    'speedMbps': speedMbps,
                    'latency': 0,
                });
            },
            onError: (error) {
                if (!completer.isCompleted) {
                    completer.completeError(error);
                }
            },
        );

        return completer.future;
    }
}