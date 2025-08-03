import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'notification_service.dart';
import 'chat_page.dart';
import 'user_profile_page.dart';
import 'social_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında bildirimleri okundu olarak işaretle
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      await NotificationService.markNotificationsAsRead(_auth.currentUser!.uid);
    } catch (e) {
      print('❌ Bildirimler işaretlenemedi: $e');
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'message':
        return '💬';
      case 'friend_request':
        return '👥';
      case 'match':
        return '🎯';
      case 'new_post':
        return '📝';
      case 'like':
        return '❤️';
      case 'comment':
        return '💭';
      case 'follow':
        return '👤';
      case 'birthday':
        return '🎂';
      case 'call':
        return '📞';
      case 'announcement':
        return '🔔';
      default:
        return '📢';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'message':
        return Colors.blue;
      case 'friend_request':
        return Colors.green;
      case 'match':
        return Colors.purple;
      case 'new_post':
        return Colors.orange;
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.teal;
      case 'follow':
        return Colors.indigo;
      case 'birthday':
        return Colors.pink;
      case 'call':
        return Colors.amber;
      case 'announcement':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final data = notification['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'message':
        if (data != null && data['senderId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverId: data['senderId'],
                receiverName: data['senderName'] ?? 'Bilinmeyen',
              ),
            ),
          );
        }
        break;
      case 'friend_request':
        if (data != null && data['senderId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(
                userId: data['senderId'],
              ),
            ),
          );
        }
        break;
      case 'match':
        if (data != null && data['matchedUserId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverId: data['matchedUserId'],
                receiverName: data['matchedUserName'] ?? 'Bilinmeyen',
              ),
            ),
          );
        }
        break;
      case 'new_post':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SocialPage(),
          ),
        );
        break;
      case 'like':
      case 'comment':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SocialPage(),
          ),
        );
        break;
      case 'follow':
        if (data != null && data['followerId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(
                userId: data['followerId'],
              ),
            ),
          );
        }
        break;
      case 'call':
        // Arama bildirimi için özel işlem gerekebilir
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.notifications,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bildirimler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bildirimler yüklenirken hata oluştu',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz bildiriminiz yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeni aktiviteler olduğunda burada görünecek',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index].data() as Map<String, dynamic>;
                final type = notification['type'] as String? ?? 'unknown';
                final title = notification['title'] as String? ?? 'Bildirim';
                final body = notification['body'] as String? ?? '';
                final timestamp = notification['timestamp'] as Timestamp?;
                final isRead = notification['isRead'] as bool? ?? false;
                final data = notification['data'] as Map<String, dynamic>?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isRead 
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead 
                          ? Theme.of(context).colorScheme.outline.withOpacity(0.2)
                          : _getNotificationColor(type).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleNotificationTap(notification),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bildirim ikonu
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getNotificationColor(type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  _getNotificationIcon(type),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Bildirim içeriği
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                            color: isRead 
                                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _getNotificationColor(type),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (timestamp != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Ok işareti
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
} 