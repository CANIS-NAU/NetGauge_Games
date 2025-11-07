import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  int get measurementsTaken => _userData?['measurementsTaken'] ?? 0;
  String get uid => _userData?['uid'] ?? '';
  int get distanceTraveled => _userData?['distanceTraveled'] ?? 0;

  Future<void> fetchUserData(String documentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(documentId)
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void updateMeasurementsTaken(int value) {
    if (_userData != null) {
      _userData!['measurementsTaken'] = value;
      notifyListeners();
    }
  }
}