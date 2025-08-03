import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  system,
  message,
}

class AppNotification {
  final String id;
  final String userId; // Bildirimi alan kullanıcı
  final String? senderId; // Bildirimi gönderen kullanıcı (null olabilir)
  final String? senderName;
  final String? senderImageUrl;
  final NotificationType type;
  final String title;
  final String message;
  final String? postId; // İlgili gönderi ID'si
  final String? commentId; // İlgili yorum ID'si
  final Timestamp timestamp;
  final bool isRead;
  final Map<String, dynamic>? data; // Ek veriler

  AppNotification({
    required this.id,
    required this.userId,
    this.senderId,
    this.senderName,
    this.senderImageUrl,
    required this.type,
    required this.title,
    required this.message,
    this.postId,
    this.commentId,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'type': type.name,
      'title': title,
      'message': message,
      'postId': postId,
      'commentId': commentId,
      'timestamp': timestamp,
      'isRead': isRead,
      'data': data,
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      userId: map['userId'] ?? '',
      senderId: map['senderId'],
      senderName: map['senderName'],
      senderImageUrl: map['senderImageUrl'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      postId: map['postId'],
      commentId: map['commentId'],
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isRead: map['isRead'] ?? false,
      data: map['data'],
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? senderName,
    String? senderImageUrl,
    NotificationType? type,
    String? title,
    String? message,
    String? postId,
    String? commentId,
    Timestamp? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImageUrl: senderImageUrl ?? this.senderImageUrl,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
} 