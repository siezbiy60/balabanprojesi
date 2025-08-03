import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_profile_page.dart';
import 'chat_page.dart';

class NearbyUsersPage extends StatefulWidget {
  const NearbyUsersPage({super.key});

  @override
  State<NearbyUsersPage> createState() => _NearbyUsersPageState();
}

class _NearbyUsersPageState extends State<NearbyUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> _getNearbyUsersStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore.collection('users').doc(currentUser.uid).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) return <Map<String, dynamic>>[];
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final currentUserCity = userData['city'] as String?;
      
      if (currentUserCity == null || currentUserCity.isEmpty) {
        print('👤 Kullanıcının şehir bilgisi yok');
        return <Map<String, dynamic>>[];
      }

      print('🏙️ Kullanıcının şehri: $currentUserCity');

      // Aynı şehirdeki kullanıcıları getir
      final nearbyUsersQuery = await _firestore
          .collection('users')
          .where('city', isEqualTo: currentUserCity)
          .get();

      print('🔄 Yakınımdaki kullanıcılar güncellendi: ${nearbyUsersQuery.docs.length} kullanıcı');

      final users = <Map<String, dynamic>>[];
      for (final doc in nearbyUsersQuery.docs) {
        final nearbyUserData = doc.data();
        
        // Kendimizi listeden çıkar
        if (doc.id != currentUser.uid) {
          users.add({
            'id': doc.id,
            ...nearbyUserData,
          });
        }
      }

      // Son aktif olanlara göre sırala
      users.sort((a, b) {
        final lastActiveA = a['lastActive'] as Timestamp?;
        final lastActiveB = b['lastActive'] as Timestamp?;
        
        if (lastActiveA == null && lastActiveB == null) return 0;
        if (lastActiveA == null) return 1;
        if (lastActiveB == null) return -1;
        
        return lastActiveB.compareTo(lastActiveA); // Yeniden eskiye
      });

      return users.take(50).toList();
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

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    final now = DateTime.now();
    final lastSeen = timestamp.toDate();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getNearbyUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('❌ Yakınımdaki kullanıcılar hatası: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Yakınımdaki kullanıcılar yüklenirken hata oluştu',
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
                    'Yakınımdaki kullanıcılar yükleniyor...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final nearbyUsers = snapshot.data ?? [];

          if (nearbyUsers.isEmpty) {
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
                      Icons.location_on,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Yakınında kimse yok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aynı şehirde yaşayan kullanıcılar burada görünür',
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
            itemCount: nearbyUsers.length,
            itemBuilder: (context, index) {
              final user = nearbyUsers[index];
              final userName = user['name'] as String? ?? 'Bilinmeyen Kullanıcı';
              final userImage = user['profileImageUrl'] as String?;
              final lastActive = user['lastActive'] as Timestamp?;
              final city = user['city'] as String? ?? '';
              final isOnline = user['isOnline'] as bool? ?? false;

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
                      // Konum ikonu
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      SizedBox(width: 12),
                      // Profil fotoğrafı
                      Stack(
                        children: [
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
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        isOnline ? 'Çevrimiçi' : 'Son görülme: ${_formatLastSeen(lastActive)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline 
                              ? Colors.green.shade600 
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
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