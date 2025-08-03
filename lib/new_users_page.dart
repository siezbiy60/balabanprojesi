import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_profile_page.dart';
import 'chat_page.dart';

class NewUsersPage extends StatefulWidget {
  const NewUsersPage({super.key});

  @override
  State<NewUsersPage> createState() => _NewUsersPageState();
}

class _NewUsersPageState extends State<NewUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> _getNewUsersStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Son 30 gün içinde kayıt olan kullanıcıları getir
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    final thirtyDaysAgoTimestamp = Timestamp.fromDate(thirtyDaysAgo);

    return _firestore
        .collection('users')
        .where('createdAt', isGreaterThan: thirtyDaysAgoTimestamp)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          print('🔄 Yeni kullanıcılar güncellendi: ${snapshot.docs.length} kullanıcı');
          
          final users = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final userData = doc.data();
            
            // Kendimizi listeden çıkar
            if (doc.id != currentUser.uid) {
              users.add({
                'id': doc.id,
                ...userData,
              });
            }
          }
          
          // En yeni kayıt olanları üstte göster
          users.sort((a, b) {
            final createdAtA = a['createdAt'] as Timestamp?;
            final createdAtB = b['createdAt'] as Timestamp?;
            
            if (createdAtA == null && createdAtB == null) return 0;
            if (createdAtA == null) return 1;
            if (createdAtB == null) return -1;
            
            return createdAtB.compareTo(createdAtA); // Yeniden eskiye
          });
          
          return users.take(20).toList();
        });
  }

  void _viewProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

  void _startChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          receiverId: userId,
          receiverName: userName,
        ),
      ),
    );
  }

  String _formatJoinDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    final now = DateTime.now();
    final joinDate = timestamp.toDate();
    final difference = now.difference(joinDate);
    
    if (difference.inDays == 0) {
      return 'Bugün katıldı';
    } else if (difference.inDays == 1) {
      return 'Dün katıldı';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce katıldı';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks hafta önce katıldı';
    } else {
      return '${joinDate.day}/${joinDate.month}/${joinDate.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getNewUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('❌ Yeni kullanıcılar hatası: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Yeni kullanıcılar yüklenirken hata oluştu',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Yeni kullanıcılar yükleniyor...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final newUsers = snapshot.data ?? [];

          if (newUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Henüz yeni kullanıcı yok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Yeni katılan kullanıcılar burada görünecek',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: newUsers.length,
            itemBuilder: (context, index) {
              final user = newUsers[index];
              final userName = user['name'] as String? ?? 'Bilinmeyen Kullanıcı';
              final userImage = user['profileImageUrl'] as String?;
              final createdAt = user['createdAt'] as Timestamp?;

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Yeni rozeti
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'YENİ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Profil fotoğrafı
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                              spreadRadius: 0,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: userImage != null
                              ? CachedNetworkImageProvider(userImage)
                              : null,
                          backgroundColor: userImage == null ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : null,
                          child: userImage == null
                              ? Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    _formatJoinDate(createdAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.chat_bubble_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          onPressed: () => _startChat(user['id'], userName),
                          tooltip: 'Mesaj Gönder',
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.person_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          onPressed: () => _viewProfile(user['id']),
                          tooltip: 'Profili Görüntüle',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}