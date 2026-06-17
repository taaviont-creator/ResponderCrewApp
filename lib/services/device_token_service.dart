import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class DeviceTokenService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _deviceTokens =>
      _firestore.collection('userDeviceTokens');

  Future<bool> saveCurrentToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token == null || token.trim().isEmpty) return false;
    return saveTokenForCurrentUser(token);
  }

  Future<bool> saveTokenForCurrentUser(String token) async {
    final user = _auth.currentUser;
    final normalizedToken = token.trim();
    final platform = _platformName;
    if (user == null || normalizedToken.isEmpty || platform == null) {
      return false;
    }

    final doc = _deviceTokens.doc(_deviceTokenId(user.uid, normalizedToken));
    final updateData = {
      'token': normalizedToken,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
      'enabled': true,
      'app': 'respondcrew',
    };

    final snapshot = await doc.get();
    if (snapshot.exists) {
      await doc.update(updateData);
      return true;
    }

    await doc.set({
      'userId': user.uid,
      ...updateData,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  String _deviceTokenId(String uid, String token) {
    final tokenKey = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    return '${uid}_$tokenKey';
  }

  String? get _platformName {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return null;
  }
}
