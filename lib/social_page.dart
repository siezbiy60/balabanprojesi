import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'user_profile_page.dart';
import 'create_post_page.dart';
import 'login_page.dart';
import 'comments_page.dart';
import 'services/comment_service.dart';
import 'services/notification_service.dart';
import 'search_page.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLiking = false;

  bool _isLiked(Map<String, dynamic> post) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;
    final likes = List<String>.from(post['likes'] ?? []);
    return likes.contains(currentUserId);
  }

  int _getLikeCount(Map<String, dynamic> post) {
    final likes = List<String>.from(post['likes'] ?? []);
    return likes.length;
  }

  int _getCommentCount(Map<String, dynamic> post) {
    // Önce commentCount alanını kontrol et
    if (post['commentCount'] != null) {
      return post['commentCount'] as int;
    }
    
    // Eğer commentCount yoksa, eski yöntemi kullan
    final comments = List<dynamic>.from(post['comments'] ?? []);
    return comments.length;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Az önce';
    
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);
    
    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return DateFormat('dd.MM.yyyy').format(postTime);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    if (_isLiking) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isLiking = true);

    try {
      final postRef = _firestore.collection('posts').doc(post['id']);
      final likes = List<String>.from(post['likes'] ?? []);

      if (_isLiked(post)) {
        likes.remove(currentUserId);
      } else {
        likes.add(currentUserId);
      }

      await postRef.update({'likes': likes});

      // Beğeni bildirimi gönder
      if (!_isLiked(post)) {
        await NotificationService.createLikeNotification(
          postUserId: post['userId'],
          postId: post['id'],
          postContent: post['content'] ?? '',
        );
      }

      // Post verilerini güncelle
      post['likes'] = likes;
      setState(() {});
    } catch (e) {
      print('Beğeni hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beğeni işlemi başarısız: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() => _isLiking = false);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Sadece kendi gönderisini silebilir
    if (post['userId'] != currentUserId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gönderiyi Sil'),
        content: const Text('Bu gönderiyi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('posts').doc(post['id']).update({
        'isDeleted': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gönderi başarıyla silindi'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      print('Gönderi silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gönderi silinemedi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    final userName = post['userName'] as String? ?? 'Bilinmeyen Kullanıcı';
    final userImage = post['userImageUrl'] as String?;
    final content = post['content'] as String? ?? '';
    final imageUrl = post['imageUrl'] as String?;
    final timestamp = post['timestamp'] as Timestamp?;
    final userId = post['userId'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kullanıcı Bilgisi
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showUserProfile(userId ?? ''),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: userImage != null
                        ? CachedNetworkImageProvider(userImage)
                        : null,
                    backgroundColor: userImage == null ? theme.colorScheme.primary.withOpacity(0.2) : null,
                    child: userImage == null
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showUserProfile(userId ?? ''),
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'report':
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bildirim özelliği yakında eklenecek')),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Bildir'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // İçerik
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),

          // Resim
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 250, // Biraz daha yüksek
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain, // Sığdırma modu
                  memCacheWidth: 800, // Bellek cache boyutu
                  memCacheHeight: 800, // Bellek cache boyutu
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        Icons.error,
                        color: theme.colorScheme.error,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Aksiyon Butonları
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Beğeni Butonu
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked(post) ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked(post) 
                            ? theme.colorScheme.error 
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getLikeCount(post)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                                 // Yorum Butonu
                 GestureDetector(
                   onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => CommentsPage(
                           postId: post['id'],
                           postContent: content,
                           postUserName: userName,
                         ),
                       ),
                     );
                   },
                   child: Row(
                     children: [
                       Icon(
                         Icons.chat_bubble_outline,
                         color: theme.colorScheme.onSurface.withOpacity(0.6),
                         size: 24,
                       ),
                       const SizedBox(width: 8),
                       Text(
                         '${_getCommentCount(post)}',
                         style: TextStyle(
                           fontSize: 14,
                           color: theme.colorScheme.onSurface.withOpacity(0.7),
                         ),
                       ),
                     ],
                   ),
                 ),
                const SizedBox(width: 24),
                // Paylaş Butonu
                Icon(
                  Icons.share_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
                const Spacer(),
                // Silme Butonu (sadece kendi gönderilerinde)
                if (_auth.currentUser?.uid == post['userId'])
                  GestureDetector(
                    onTap: () => _deletePost(post),
                    child: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error.withOpacity(0.7),
                      size: 24,
                    ),
                  ),
                if (_auth.currentUser?.uid == post['userId'])
                  const SizedBox(width: 16),
                // Kaydet Butonu
                Icon(
                  Icons.bookmark_border,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Sosyal'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: _auth.currentUser != null ? [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
            icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onPrimary),
            tooltip: 'Ara',
          ),
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreatePostPage()),
              );
              if (result == true) {
                setState(() {});
              }
            },
            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
            tooltip: 'Yeni Gönderi',
          ),
          // Geçici buton - yorum sayılarını güncellemek için
          IconButton(
            onPressed: () async {
              try {
                await CommentService.updateAllPostCommentCounts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yorum sayıları güncellendi')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e')),
                );
              }
            },
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
            tooltip: 'Yorum Sayılarını Güncelle',
          ),
        ] : null,
      ),
      body: _auth.currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.login,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Giriş Yapın',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gönderileri görmek için giriş yapmanız gerekiyor',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                                     ElevatedButton.icon(
                     onPressed: () {
                       Navigator.pushReplacement(
                         context,
                         MaterialPageRoute(builder: (context) => const LoginPage()),
                       );
                     },
                    icon: const Icon(Icons.login),
                    label: const Text('Giriş Yap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('isDeleted', isEqualTo: false)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Social page error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Gönderiler yüklenirken hata oluştu',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lütfen internet bağlantınızı kontrol edin',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            );
          }

          final posts = snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.forum_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz gönderi yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk gönderiyi siz paylaşın!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreatePostPage()),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Gönderiyi Paylaş'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            color: Theme.of(context).colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postData = posts[index].data() as Map<String, dynamic>;
                postData['id'] = posts[index].id; // Document ID'yi ekle
                
                return _buildPostCard(postData);
              },
            ),
          );
        },
      ),
    );
  }
} 