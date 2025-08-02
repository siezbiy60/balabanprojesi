import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnlineStatusService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _isInitialized = false;

  // Kullanıcı çevrimiçi olduğunda
  static Future<void> setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastActive': FieldValue.serverTimestamp(),
    });
    _isInitialized = true;
  }

  // Kullanıcı çevrimdışı olduğunda
  static Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null || !_isInitialized) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastActive': FieldValue.serverTimestamp(),
    });
    _isInitialized = false;
  }

  // Kullanıcının son aktif zamanını güncelle
  static Future<void> updateLastActive() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
}