import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String content;
  final Timestamp timestamp;
  final List<String> likes;
  final String? parentCommentId; // Yanıt verilen yorumun ID'si
  final List<Comment> replies;
  final bool isDeleted;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.content,
    required this.timestamp,
    required this.likes,
    this.parentCommentId,
    required this.replies,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'content': content,
      'timestamp': timestamp,
      'likes': likes,
      'parentCommentId': parentCommentId,
      'isDeleted': isDeleted,
    };
  }

  factory Comment.fromMap(String id, Map<String, dynamic> map) {
    return Comment(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userImageUrl: map['userImageUrl'],
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      likes: List<String>.from(map['likes'] ?? []),
      parentCommentId: map['parentCommentId'],
      replies: [], // Replies will be loaded separately
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userImageUrl,
    String? content,
    Timestamp? timestamp,
    List<String>? likes,
    String? parentCommentId,
    List<Comment>? replies,
    bool? isDeleted,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
} 