import 'package:flutter/services.dart';

class NotificationService {
  static const platform = MethodChannel('com.example.balabanproje/notification');

  Future<void> showNotification(String message) async {
    try {
      await platform.invokeMethod('showNotification', {'message': message});
    } catch (e) {
      print("Hata: $e");
    }
  }
}