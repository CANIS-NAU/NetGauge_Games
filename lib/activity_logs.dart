import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

class LogEvent {
  final String id;         // UUID for deduplication
  final String name;       // e.g. "button_tapped"
  final Map<String, dynamic> params;  // any extra data
  final DateTime occurredAt;  // client-side timestamp

  LogEvent({
    required this.id,
    required this.name,
    required this.params,
    required this.occurredAt,
  });

  // Convert to a plain map for both Hive and Firestore
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'params': params,
    'occurredAt': occurredAt.toIso8601String(),
  };

  factory LogEvent.fromMap(Map<dynamic, dynamic> map) => LogEvent(
    id: map['id'],
    name: map['name'],
    params: Map<String, dynamic>.from(map['params']),
    occurredAt: DateTime.parse(map['occurredAt']),
  );
}

class LoggingService {
  static const String _boxName = 'event_queue';
  static const int _maxQueueSize = 500;
  static const int _batchSize = 100; // Firestore max is 500, keep lower for safety

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();
  late Box _box;
  bool _isSyncing = false;

  LoggingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Call this once at app startup
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);

    // Listen for connectivity changes and sync when back online
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncToFirestore();
      }
    });

    // Also attempt a sync on startup in case events are queued
    syncToFirestore();
  }

  // Your app calls this every time something happens
  Future<void> logEvent(String name, {Map<String, dynamic>? params, String? userId}) async {
    // Enforce queue size limit — drop oldest if full
    if (_box.length >= _maxQueueSize) {
      final oldestKey = _box.keys.first;
      await _box.delete(oldestKey);
    }

    final event = LogEvent(
      id: _uuid.v4(),
      name: name,
      params: {
        ...?params,
        if (userId != null) 'userId': userId,
      },
      occurredAt: DateTime.now(), // always client-side time
    );

    // Write to Hive immediately — this never fails due to connectivity
    await _box.put(event.id, event.toMap());
  }

  // Called automatically on connectivity change, or you can call it manually
  Future<void> syncToFirestore() async {
    if (_isSyncing || _box.isEmpty) return;
    _isSyncing = true;

    try {
      final keys = _box.keys.toList();

      // Process in batches
      for (int i = 0; i < keys.length; i += _batchSize) {
        final batchKeys = keys.skip(i).take(_batchSize).toList();
        final batch = _firestore.batch();

        for (final key in batchKeys) {
          final rawMap = _box.get(key);
          if (rawMap == null) continue;

          final event = LogEvent.fromMap(rawMap);

          // Using the event's UUID as the Firestore document ID
          // makes this write idempotent — safe to retry
          final docRef = _firestore.collection('events').doc(event.id);
          batch.set(docRef, {
            ...event.toMap(),
            'syncedAt': FieldValue.serverTimestamp(),
          });
        }

        // Only delete from local queue after confirming a successful write
        await batch.commit();
        await _box.deleteAll(batchKeys);
      }
    } catch (e) {
      // Sync failed — events stay in the local queue and will retry next time
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}