import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bildirim oluşturma
  static Future<void> createNotification({
    required String userId, // Bildirimi alacak kullanıcı
    required NotificationType type,
    required String title,
    required String message,
    String? postId,
    String? commentId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Kendine bildirim gönderme
      if (currentUser.uid == userId) return;

      // Gönderen kullanıcı bilgilerini al
      final senderDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final senderData = senderDoc.data();

      final notification = AppNotification(
        id: '',
        userId: userId,
        senderId: currentUser.uid,
        senderName: senderData?['name'] ?? 'Bilinmeyen Kullanıcı',
        senderImageUrl: senderData?['profileImageUrl'],
        type: type,
        title: title,
        message: message,
        postId: postId,
        commentId: commentId,
        timestamp: Timestamp.now(),
        data: data,
      );

      await _firestore.collection('notifications').add(notification.toMap());
      print('✅ Bildirim oluşturuldu: $type');
    } catch (e) {
      print('❌ Bildirim oluşturma hatası: $e');
    }
  }

  // Kullanıcının bildirimlerini getir
  static Stream<List<AppNotification>> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ Kullanıcı giriş yapmamış');
      return Stream.value([]);
    }

    print('📋 Bildirimler yükleniyor... Kullanıcı: ${user.uid}');

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      print('📋 Bildirimler yükleniyor... Toplam: ${snapshot.docs.length}');
      
      // Her bildirimin detaylarını yazdır
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('📋 Bildirim: ${doc.id} - Type: ${data['type']} - Title: ${data['title']} - Message: ${data['message']}');
      }
      
      try {
        final notifications = snapshot.docs
            .map((doc) {
              try {
                return AppNotification.fromMap(doc.id, doc.data());
              } catch (e) {
                print('❌ Bildirim parse hatası: ${doc.id} - $e');
                return null;
              }
            })
            .where((notification) => notification != null)
            .cast<AppNotification>()
            .toList();
        
        // Manuel sıralama (timestamp'e göre azalan)
        notifications.sort((a, b) {
          try {
            return b.timestamp.compareTo(a.timestamp);
          } catch (e) {
            print('❌ Sıralama hatası: $e');
            return 0;
          }
        });
        
        // İlk 50'yi döndür
        final result = notifications.take(50).toList();
        print('📋 Bildirimler başarıyla yüklendi: ${result.length} adet');
        
        return result;
      } catch (e) {
        print('❌ Bildirimler işlenirken hata: $e');
        return <AppNotification>[];
      }
    });
  }

  // Bildirimi okundu olarak işaretle
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
      print('✅ Bildirim okundu olarak işaretlendi');
    } catch (e) {
      print('❌ Bildirim güncelleme hatası: $e');
    }
  }

  // Tüm bildirimleri okundu olarak işaretle
  static Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Manuel filtreleme
      final unreadNotifications = notifications.docs
          .where((doc) => doc.data()['isRead'] != true)
          .toList();

      for (final doc in unreadNotifications) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('✅ Tüm bildirimler okundu olarak işaretlendi');
    } catch (e) {
      print('❌ Toplu bildirim güncelleme hatası: $e');
    }
  }

  // Okunmamış bildirim sayısını getir
  static Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['isRead'] != true)
          .length;
    });
  }

  // Beğeni bildirimi oluştur
  static Future<void> createLikeNotification({
    required String postUserId,
    required String postId,
    required String postContent,
  }) async {
    await createNotification(
      userId: postUserId,
      type: NotificationType.like,
      title: 'Yeni Beğeni',
      message: 'Gönderiniz beğenildi',
      postId: postId,
      data: {'postContent': postContent},
    );
  }

  // Yorum bildirimi oluştur
  static Future<void> createCommentNotification({
    required String postUserId,
    required String postId,
    required String commentContent,
    required String commentId,
  }) async {
    await createNotification(
      userId: postUserId,
      type: NotificationType.comment,
      title: 'Yeni Yorum',
      message: 'Gönderinize yorum yapıldı',
      postId: postId,
      commentId: commentId,
      data: {'commentContent': commentContent},
    );
  }

  // Sistem bildirimi oluştur
  static Future<void> createSystemNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.system,
      title: title,
      message: message,
      data: data,
    );
  }

  // Mesaj bildirimi oluştur
  static Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String senderId,
  }) async {
    try {
      // Kendine bildirim gönderme
      if (senderId == receiverId) {
        print('⚠️ Kendine bildirim gönderilmeye çalışılıyor: $senderId');
        return;
      }

      print('📤 Mesaj bildirimi gönderiliyor: $senderId -> $receiverId');

      // Gönderen kullanıcı bilgilerini al
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderData = senderDoc.data();

      final notification = AppNotification(
        id: '',
        userId: receiverId,
        senderId: senderId,
        senderName: senderData?['name'] ?? senderName,
        senderImageUrl: senderData?['profileImageUrl'],
        type: NotificationType.message,
        title: 'Yeni Mesaj',
        message: '$senderName: $message',
        timestamp: Timestamp.now(),
        data: {
          'senderId': senderId,
          'senderName': senderName,
          'message': message,
        },
      );

      final docRef = await _firestore.collection('notifications').add(notification.toMap());
      print('✅ Mesaj bildirimi oluşturuldu: $senderName -> $receiverId (ID: ${docRef.id})');
      print('📋 Bildirim detayları: ${notification.toMap()}');
      
      // Bildirimin gerçekten oluşturulduğunu kontrol et
      final createdDoc = await _firestore.collection('notifications').doc(docRef.id).get();
      if (createdDoc.exists) {
        print('✅ Bildirim veritabanında doğrulandı');
      } else {
        print('❌ Bildirim veritabanında bulunamadı');
      }
    } catch (e) {
      print('❌ Mesaj bildirimi oluşturma hatası: $e');
    }
  }
} 