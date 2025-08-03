import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class NotificationService {
  static const platform = MethodChannel('com.example.balabanproje/notification');

  Future<void> showNotification(String message) async {
    try {
      await platform.invokeMethod('showNotification', {'message': message});
    } catch (e) {
      print("Hata: $e");
    }
  }

  static Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📱 Push bildirimi gönderiliyor...');
      print('📱 Token: ${token.substring(0, 20)}...');
      print('📱 Title: $title');
      print('📱 Body: $body');
      print('📱 Data: $data');

      // Firestore'a da kaydetmek isterseniz, aşağıdaki satırları bırakabilirsiniz
      await FirebaseFirestore.instance.collection('notifications').add({
        'token': token,
        'title': title,
        'body': body,
        if (data != null) ...data,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // --- BULUT FONKSİYONU İLE PUSH BİLDİRİMİ ---
      final url = 'https://europe-west1-balabanproje.cloudfunctions.net/sendPushNotificationHttp';
      final message = {
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
      };

      print('📱 Cloud Function URL: $url');
      print('📱 Request body: ${jsonEncode(message)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(message),
      );

      print('📱 Cloud Function response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ Push bildirimi başarıyla gönderildi');
      } else {
        print('❌ Push bildirimi gönderilemedi: ${response.statusCode}');
      }
    } catch (e, st) {
      print('❌ Push gönderilemedi: $e\n$st');
    }
  }

  // 🔔 YENİ BİLDİRİM TÜRLERİ

  /// 📨 Mesaj Bildirimi
  static Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    String? senderId,
  }) async {
    try {
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      
      if (!receiverDoc.exists) return;
      
      final receiverData = receiverDoc.data() as Map<String, dynamic>;
      final fcmToken = receiverData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = 'Yeni Mesaj';
      final body = '$senderName: ${message.length > 50 ? '${message.substring(0, 50)}...' : message}';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'message',
          'senderId': senderId,
          'senderName': senderName,
          'message': message,
        },
      );
      
      print('✅ Mesaj bildirimi gönderildi: $receiverId');
    } catch (e) {
      print('❌ Mesaj bildirimi gönderilemedi: $e');
    }
  }

  /// 👥 Arkadaşlık İsteği Bildirimi
  static Future<void> sendFriendRequestNotification({
    required String receiverId,
    required String senderName,
    String? senderId,
  }) async {
    try {
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      
      if (!receiverDoc.exists) return;
      
      final receiverData = receiverDoc.data() as Map<String, dynamic>;
      final fcmToken = receiverData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = 'Yeni Arkadaşlık İsteği';
      final body = '$senderName size arkadaşlık isteği gönderdi';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'friend_request',
          'senderId': senderId,
          'senderName': senderName,
        },
      );
      
      print('✅ Arkadaşlık isteği bildirimi gönderildi: $receiverId');
    } catch (e) {
      print('❌ Arkadaşlık isteği bildirimi gönderilemedi: $e');
    }
  }

  /// 🎯 Eşleşme Bildirimi
  static Future<void> sendMatchNotification({
    required String userId,
    required String matchedUserName,
    String? matchedUserId,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = '🎯 Eşleşme Bulundu!';
      final body = '$matchedUserName ile eşleştiniz! Hemen sohbet edin.';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'match',
          'matchedUserId': matchedUserId,
          'matchedUserName': matchedUserName,
        },
      );
      
      print('✅ Eşleşme bildirimi gönderildi: $userId');
    } catch (e) {
      print('❌ Eşleşme bildirimi gönderilemedi: $e');
    }
  }

  /// 📝 Yeni Gönderi Bildirimi (Takip edilen kullanıcılardan)
  static Future<void> sendNewPostNotification({
    required String followerId,
    required String posterName,
    required String postContent,
    String? posterId,
    String? postId,
  }) async {
    try {
      final followerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(followerId)
          .get();
      
      if (!followerDoc.exists) return;
      
      final followerData = followerDoc.data() as Map<String, dynamic>;
      final fcmToken = followerData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = 'Yeni Gönderi';
      final body = '$posterName yeni bir gönderi paylaştı';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'new_post',
          'posterId': posterId,
          'posterName': posterName,
          'postId': postId,
          'postContent': postContent,
        },
      );
      
      print('✅ Yeni gönderi bildirimi gönderildi: $followerId');
    } catch (e) {
      print('❌ Yeni gönderi bildirimi gönderilemedi: $e');
    }
  }

  /// ❤️ Beğeni Bildirimi
  static Future<void> sendLikeNotification({
    required String postOwnerId,
    required String likerName,
    required String postContent,
    String? likerId,
    String? postId,
  }) async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(postOwnerId)
          .get();
      
      if (!ownerDoc.exists) return;
      
      final ownerData = ownerDoc.data() as Map<String, dynamic>;
      final fcmToken = ownerData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = 'Yeni Beğeni';
      final body = '$likerName gönderinizi beğendi';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'like',
          'likerId': likerId,
          'likerName': likerName,
          'postId': postId,
          'postContent': postContent,
        },
      );
      
      print('✅ Beğeni bildirimi gönderildi: $postOwnerId');
    } catch (e) {
      print('❌ Beğeni bildirimi gönderilemedi: $e');
    }
  }

  /// 💬 Yorum Bildirimi
  static Future<void> sendCommentNotification({
    required String postOwnerId,
    required String commenterName,
    required String comment,
    String? commenterId,
    String? postId,
  }) async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(postOwnerId)
          .get();
      
      if (!ownerDoc.exists) return;
      
      final ownerData = ownerDoc.data() as Map<String, dynamic>;
      final fcmToken = ownerData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = 'Yeni Yorum';
      final body = '$commenterName gönderinize yorum yaptı';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'comment',
          'commenterId': commenterId,
          'commenterName': commenterName,
          'postId': postId,
          'comment': comment,
        },
      );
      
      print('✅ Yorum bildirimi gönderildi: $postOwnerId');
    } catch (e) {
      print('❌ Yorum bildirimi gönderilemedi: $e');
    }
  }

  /// 👤 Takip Bildirimi
  static Future<void> sendFollowNotification({
    required String followedId,
    required String followerName,
    String? followerId,
  }) async {
    try {
      final followedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(followedId)
          .get();
      
      if (!followedDoc.exists) return;
      
      final followedData = followedDoc.data() as Map<String, dynamic>;
      final fcmToken = followedData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = 'Yeni Takipçi';
      final body = '$followerName sizi takip etmeye başladı';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'follow',
          'followerId': followerId,
          'followerName': followerName,
        },
      );
      
      print('✅ Takip bildirimi gönderildi: $followedId');
    } catch (e) {
      print('❌ Takip bildirimi gönderilemedi: $e');
    }
  }

  /// 🎉 Doğum Günü Bildirimi
  static Future<void> sendBirthdayNotification({
    required String userId,
    required String friendName,
    String? friendId,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) return;
      
      final title = '🎂 Doğum Günü!';
      final body = '$friendName\'in doğum günü bugün! Kutlamayı unutmayın.';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'birthday',
          'friendId': friendId,
          'friendName': friendName,
        },
      );
      
      print('✅ Doğum günü bildirimi gönderildi: $userId');
    } catch (e) {
      print('❌ Doğum günü bildirimi gönderilemedi: $e');
    }
  }

  /// 🔔 Genel Duyuru Bildirimi
  static Future<void> sendAnnouncementNotification({
    required String title,
    required String body,
    List<String>? targetUserIds, // Belirli kullanıcılar için
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      
      if (targetUserIds != null && targetUserIds.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: targetUserIds);
      }
      
      final querySnapshot = await query.get();
      
      for (final doc in querySnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'] as String?;
        
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await sendPushNotification(
            token: fcmToken,
            title: title,
            body: body,
            data: {
              'type': 'announcement',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
        }
      }
      
      print('✅ Duyuru bildirimi gönderildi');
    } catch (e) {
      print('❌ Duyuru bildirimi gönderilemedi: $e');
    }
  }

  /// 📞 Arama Bildirimi (Mevcut)
  static Future<void> sendCallNotification({
    required String receiverId,
    required String callerName,
    required String callId,
    required String callType,
    String? callerId,
  }) async {
    try {
      // Karşı tarafın FCM token'ını al
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      
      if (!receiverDoc.exists) {
        throw Exception('Alıcı kullanıcı bulunamadı');
      }
      
      final receiverData = receiverDoc.data() as Map<String, dynamic>;
      final fcmToken = receiverData['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        throw Exception('Alıcının FCM token\'ı bulunamadı');
      }
      
      // Arama bildirimi gönder
      final callTypeText = callType == 'voice' ? 'sesli arama' : 'görüntülü arama';
      final title = 'Gelen Arama';
      final body = '$callerName size $callTypeText yapıyor';
      
      await sendPushNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': 'call',
          'callId': callId,
          'callType': callType,
          'callerId': callerId ?? receiverId,
        },
      );
      
      print('Arama bildirimi gönderildi: $receiverId');
    } catch (e) {
      print('Arama bildirimi gönderilemedi: $e');
      rethrow;
    }
  }

  /// 🔄 Bildirim Geçmişini Kaydet
  static Future<void> saveNotificationHistory({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'body': body,
        if (data != null) ...data,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('✅ Bildirim geçmişi kaydedildi: $userId');
    } catch (e) {
      print('❌ Bildirim geçmişi kaydedilemedi: $e');
    }
  }

  /// 📋 Bildirimleri Okundu Olarak İşaretle
  static Future<void> markNotificationsAsRead(String userId) async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
      print('✅ Bildirimler okundu olarak işaretlendi: $userId');
    } catch (e) {
      print('❌ Bildirimler işaretlenemedi: $e');
    }
  }
}