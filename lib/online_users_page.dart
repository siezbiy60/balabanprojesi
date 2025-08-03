import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_page.dart';
import 'user_profile_page.dart';

class OnlineUsersPage extends StatefulWidget {
  const OnlineUsersPage({super.key});

  @override
  State<OnlineUsersPage> createState() => _OnlineUsersPageState();
}

class _OnlineUsersPageState extends State<OnlineUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOnlineUsers();
  }

  Future<void> _loadOnlineUsers() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Çevrimiçi kullanıcıları al (son 5 dakika içinde aktif olanlar)
      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
      final fiveMinutesAgoTimestamp = Timestamp.fromDate(fiveMinutesAgo);
      
      final querySnapshot = await _firestore
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .where('lastActive', isGreaterThan: fiveMinutesAgoTimestamp)
          .get();

      final users = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final userData = doc.data();
        // Kendimizi listeden çıkar
        if (doc.id != currentUser.uid) {
          users.add({
            'id': doc.id,
            ...userData,
          });
        }
      }

      setState(() {
        _onlineUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Çevrimiçi kullanıcılar yüklenirken hata: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(String userId, String userName) async {
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

  void _viewProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
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
                Icons.people_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Çevrimiçi Kullanıcılar',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary, size: 24),
              onPressed: _loadOnlineUsers,
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Çevrimiçi kullanıcılar yükleniyor...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _onlineUsers.isEmpty
              ? Center(
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
                          Icons.people_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Şu anda çevrimiçi kullanıcı yok',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Diğer kullanıcılar çevrimiçi olduğunda\nburada görünecekler',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Yenile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _loadOnlineUsers,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOnlineUsers,
                  color: Theme.of(context).colorScheme.primary,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _onlineUsers.length,
                    itemBuilder: (context, index) {
                      final user = _onlineUsers[index];
                      final userName = user['name'] as String? ?? 'Bilinmeyen Kullanıcı';
                      final userImage = user['profileImageUrl'] as String?;
                      final lastActive = user['lastActive'] as Timestamp?;
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
                          leading: Stack(
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
                          title: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            isOnline ? 'Çevrimiçi' : 'Son görülme: ${_formatLastSeen(lastActive)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isOnline ? Colors.green.shade600 : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
} 