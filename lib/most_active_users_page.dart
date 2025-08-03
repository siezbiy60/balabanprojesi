import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_profile_page.dart';

class MostActiveUsersPage extends StatefulWidget {
  const MostActiveUsersPage({super.key});

  @override
  State<MostActiveUsersPage> createState() => _MostActiveUsersPageState();
}

class _MostActiveUsersPageState extends State<MostActiveUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> _getMostActiveUsersStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Tüm kullanıcıları getir (online/offline fark etmez)
    // Önce totalActiveTime'a göre sıralamayı dene, yoksa tüm kullanıcıları getir
    return _firestore
        .collection('users')
        .limit(50) // Daha fazla kullanıcı getir sonra client-side sırala
        .snapshots()
        .map((snapshot) {
          print('🔄 En aktif kullanıcılar güncellendi: ${snapshot.docs.length} kullanıcı');
          
          final users = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final userData = doc.data();
            
            // Kendimizi listeden çıkar
            if (doc.id != currentUser.uid) {
              // totalActiveTime yoksa 0 olarak varsay
              final totalActiveTime = userData['totalActiveTime'] as int? ?? 0;
              
              users.add({
                'id': doc.id,
                'totalActiveTime': totalActiveTime,
                ...userData,
              });
            }
          }
          
          // Client-side'da totalActiveTime'a göre tekrar sırala (güvenlik için)
          users.sort((a, b) {
            final timeA = a['totalActiveTime'] as int? ?? 0;
            final timeB = b['totalActiveTime'] as int? ?? 0;
            return timeB.compareTo(timeA); // Büyükten küçüğe
          });
          
          // En aktif 20 kullanıcıyı al
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

  String _formatActiveTime(int? totalMinutes) {
    if (totalMinutes == null || totalMinutes == 0) return 'Yeni kullanıcı';
    
    if (totalMinutes < 60) {
      return '${totalMinutes} dakika';
    } else if (totalMinutes < 1440) { // 24 saat
      final hours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes > 0) {
        return '${hours}sa ${remainingMinutes}dk';
      }
      return '${hours} saat';
    } else {
      final days = totalMinutes ~/ 1440;
      final remainingHours = (totalMinutes % 1440) ~/ 60;
      if (remainingHours > 0) {
        return '${days}g ${remainingHours}sa';
      }
      return '${days} gün';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.trending_up,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'En Aktif Kullanıcılar',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Kullanıcı sayısını göster
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getMostActiveUsersStream(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                if (count == 0) return SizedBox.shrink();
                
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getMostActiveUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('❌ En aktif kullanıcılar hatası: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'En aktif kullanıcılar yüklenirken hata oluştu',
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
                    'En aktif kullanıcılar yükleniyor...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final activeUsers = snapshot.data ?? [];

          if (activeUsers.isEmpty) {
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
                      Icons.trending_up,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Henüz aktif kullanıcı yok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kullanıcılar aktif oldukça burada görünecekler',
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
            itemCount: activeUsers.length,
            itemBuilder: (context, index) {
              final user = activeUsers[index];
              final userName = user['name'] as String? ?? 'Bilinmeyen Kullanıcı';
              final userImage = user['profileImageUrl'] as String?;
              final totalActiveTime = user['totalActiveTime'] as int?;

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
                      // Sıralama numarası
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index < 3 
                              ? (index == 0 ? Colors.amber : index == 1 ? Colors.grey.shade400 : Colors.brown.shade400)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: index < 3 ? Colors.white : Theme.of(context).colorScheme.primary,
                            ),
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
                    'Toplam aktif süre: ${_formatActiveTime(totalActiveTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  trailing: Container(
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}