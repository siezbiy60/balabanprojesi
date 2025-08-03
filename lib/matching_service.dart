import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class MatchingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CollectionReference _queue = _firestore.collection('matching_queue');

  /// Uygulama başladığında çağrılacak - eski kayıtları temizle
  static Future<void> initialize() async {
    print('🚀 MatchingService başlatılıyor...');
    await _cleanupOldEntries();
    print('✅ MatchingService hazır');
  }

  /// Rastgele eşleşme başlatır. Eşleşme olursa callId döner, yoksa null.
  static Future<String?> findMatchAndStartCall() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ Kullanıcı oturum açmamış!');
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    
    print('🔍 Eşleşme aranıyor... Kullanıcı: ${user.uid}');

    try {
      // Önce eski kayıtları temizle (1 dakikadan eski)
      await _cleanupOldEntries();
      
      // Kullanıcı zaten kuyrukta mı kontrol et
      final existingDoc = await _queue.doc(user.uid).get();
      if (existingDoc.exists) {
        print('⚠️ Kullanıcı zaten kuyrukta, eski kayıt siliniyor: ${user.uid}');
        await _queue.doc(user.uid).delete();
      }
      
      // Kendini kuyruğa ekle
      await _queue.doc(user.uid).set({
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'matchedWith': null,
        'callId': null,
        'isCaller': null,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      print('✅ Kullanıcı kuyruğa eklendi: ${user.uid}');
      
      // Kuyrukta bekleyen başka kullanıcı var mı kontrol et
      final thirtySecondsAgo = DateTime.now().subtract(Duration(seconds: 30));
      final waitingUsers = await _queue
          .where('matchedWith', isEqualTo: null)
          .where('lastActivity', isGreaterThan: thirtySecondsAgo)
          .get();
      
      print('📊 Kuyrukta aktif bekleyen kullanıcı sayısı: ${waitingUsers.docs.length}');

      // Kendisi hariç başka bekleyen var mı?
      final otherWaiting = waitingUsers.docs.where((doc) => doc.id != user.uid).toList();
      
      print('🔍 Diğer bekleyen kullanıcılar:');
      for (var doc in otherWaiting) {
        final data = doc.data() as Map<String, dynamic>;
        final lastActivity = data['lastActivity'] as Timestamp?;
        final timeDiff = lastActivity != null ? 
          DateTime.now().difference(lastActivity.toDate()).inSeconds : 'unknown';
        print('  - ${doc.id}: lastActivity ${timeDiff}s ago');
      }
      
      if (otherWaiting.isNotEmpty) {
        // En eski bekleyen kullanıcıyı al
        otherWaiting.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
        final other = otherWaiting.first;
        final otherUid = other['uid'];
        final callId = '${user.uid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}';
        
        print('🎯 Kuyrukta bekleyen kullanıcı bulundu! Kullanıcı: ${user.uid} <-> ${otherUid}, CallId: $callId');
        
        // Her iki kullanıcıya da matchedWith ve callId yaz
        await _queue.doc(other.id).update({
          'matchedWith': user.uid, 
          'callId': callId,
          'isCaller': false,  // Diğer kullanıcı aranan (callee)
          'lastActivity': FieldValue.serverTimestamp(),
        });
        print('✅ Diğer kullanıcı güncellendi: ${other.id}');
        
        await _queue.doc(user.uid).update({
          'matchedWith': otherUid, 
          'callId': callId,
          'isCaller': true,  // Bu kullanıcı arayan (caller)
          'lastActivity': FieldValue.serverTimestamp(),
        });
        print('✅ Bu kullanıcı güncellendi: ${user.uid}');

        // Eşleşme bildirimleri gönder
        try {
          // Kullanıcı isimlerini al
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          final otherUserDoc = await _firestore.collection('users').doc(otherUid).get();
          
          final userName = userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['name'] ?? 'Bilinmeyen' : 'Bilinmeyen';
          final otherUserName = otherUserDoc.exists ? (otherUserDoc.data() as Map<String, dynamic>)['name'] ?? 'Bilinmeyen' : 'Bilinmeyen';
          
          // Diğer kullanıcıya bildirim gönder
          await NotificationService.sendMatchNotification(
            userId: otherUid,
            matchedUserName: userName,
            matchedUserId: user.uid,
          );
          
          // Bu kullanıcıya bildirim gönder
          await NotificationService.sendMatchNotification(
            userId: user.uid,
            matchedUserName: otherUserName,
            matchedUserId: otherUid,
          );
          
          print('✅ Eşleşme bildirimleri gönderildi');
        } catch (e) {
          print('❌ Eşleşme bildirimi gönderilemedi: $e');
        }

        return callId;
      } else {
        // Kuyrukta bekleyen başka kullanıcı yok, sadece bekler
        print('⏳ Kuyrukta bekleyen başka kullanıcı yok, eşleşme için bekleniyor...');
        return null;
      }
    } catch (e) {
      print('❌ Eşleşme hatası: $e');
      return null;
    }
  }

  /// Kullanıcıya eşleşme geldiğinde dinler
  static Stream<DocumentSnapshot> listenForMatch() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _queue.doc(user.uid).snapshots();
  }

  /// Kuyruktan çık (eşleşmeyi iptal et)
  static Future<void> leaveQueue() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Önce kullanıcının mevcut durumunu kontrol et
      final userDoc = await _queue.doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final matchedWith = data['matchedWith'];
        
        // Eğer eşleşmişse, diğer kullanıcıyı da kuyruktan çıkar
        if (matchedWith != null) {
          await _queue.doc(matchedWith).delete();
          print('✅ Eşleşilen kullanıcı da kuyruktan çıkarıldı: $matchedWith');
        }
      }
      
      // Kendini kuyruktan çıkar
      await _queue.doc(user.uid).delete();
      print('✅ Kullanıcı kuyruktan çıkarıldı: ${user.uid}');
    } catch (e) {
      print('❌ Kuyruktan çıkma hatası: $e');
    }
  }

  /// Test için: Tüm kullanıcıları kuyruktan temizle
  static Future<void> clearAllQueue() async {
    try {
      final allUsers = await _queue.get();
      for (var doc in allUsers.docs) {
        await doc.reference.delete();
      }
      print('🧹 Tüm kullanıcılar kuyruktan temizlendi');
    } catch (e) {
      print('❌ Kuyruk temizleme hatası: $e');
    }
  }

  /// Test için: Kuyruktaki tüm kullanıcıları listele
  static Future<void> listAllInQueue() async {
    try {
      final allUsers = await _queue.get();
      print('📋 Kuyruktaki kullanıcılar:');
      for (var doc in allUsers.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('  - ${doc.id}: ${data['uid']} (matchedWith: ${data['matchedWith']})');
      }
    } catch (e) {
      print('❌ Kuyruk listeleme hatası: $e');
    }
  }

  /// Eski kayıtları temizle (1 dakikadan eski)
  static Future<void> _cleanupOldEntries() async {
    try {
      final oneMinuteAgo = DateTime.now().subtract(Duration(minutes: 1));
      final oldEntries = await _queue
          .where('lastActivity', isLessThan: oneMinuteAgo)
          .get();
      
      if (oldEntries.docs.isNotEmpty) {
        print('🧹 ${oldEntries.docs.length} eski kayıt temizleniyor...');
        for (var doc in oldEntries.docs) {
          await doc.reference.delete();
          print('🗑️ Eski kayıt silindi: ${doc.id}');
        }
        print('✅ Eski kayıtlar temizlendi');
      }
    } catch (e) {
      print('❌ Eski kayıt temizleme hatası: $e');
    }
  }
}