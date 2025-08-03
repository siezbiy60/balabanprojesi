import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'user_profile_page.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onRefresh;

  const PostCard({
    super.key,
    required this.post,
    this.onRefresh,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLiking = false;

  bool get _isLiked {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;
    final likes = List<String>.from(widget.post['likes'] ?? []);
    return likes.contains(currentUserId);
  }

  int get _likeCount {
    final likes = List<String>.from(widget.post['likes'] ?? []);
    return likes.length;
  }

  int get _commentCount {
    final comments = List<dynamic>.from(widget.post['comments'] ?? []);
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

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isLiking = true);

    try {
      final postRef = _firestore.collection('posts').doc(widget.post['id']);
      final likes = List<String>.from(widget.post['likes'] ?? []);

      if (_isLiked) {
        likes.remove(currentUserId);
      } else {
        likes.add(currentUserId);
      }

      await postRef.update({'likes': likes});

      // Post verilerini güncelle
      widget.post['likes'] = likes;
      
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
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

  Future<void> _deletePost() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Sadece kendi gönderisini silebilir
    if (widget.post['userId'] != currentUserId) return;

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
      await _firestore.collection('posts').doc(widget.post['id']).update({
        'isDeleted': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gönderi başarıyla silindi'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
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

  void _showUserProfile() {
    final userId = widget.post['userId'];
    if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(userId: userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kullanıcı Bilgisi
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showUserProfile,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.post['userImageUrl'] != null
                        ? CachedNetworkImageProvider(widget.post['userImageUrl'])
                        : null,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: widget.post['userImageUrl'] == null
                        ? Icon(
                            Icons.person,
                            color: theme.colorScheme.primary,
                            size: 20,
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _showUserProfile,
                        child: Text(
                          widget.post['userName'] ?? 'Bilinmeyen Kullanıcı',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(widget.post['timestamp']),
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
                          SnackBar(content: Text('Bildirim özelliği yakında eklenecek')),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
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
          if (widget.post['content'] != null && widget.post['content'].isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.post['content'],
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),

          // Resim
          if (widget.post['imageUrl'] != null && widget.post['imageUrl'].isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 250, // Biraz daha yüksek
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.post['imageUrl'],
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
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Beğeni Butonu
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked 
                            ? theme.colorScheme.error 
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '$_likeCount',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                // Yorum Butonu
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$_commentCount',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 24),
                // Paylaş Butonu
                Icon(
                  Icons.share_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
                Spacer(),
                // Silme Butonu (sadece kendi gönderilerinde)
                if (_auth.currentUser?.uid == widget.post['userId'])
                  GestureDetector(
                    onTap: _deletePost,
                    child: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error.withOpacity(0.7),
                      size: 24,
                    ),
                  ),
                if (_auth.currentUser?.uid == widget.post['userId'])
                  SizedBox(width: 16),
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
} 