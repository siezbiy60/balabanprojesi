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
}