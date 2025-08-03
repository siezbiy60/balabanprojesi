import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment.dart';
import 'notification_service.dart';

class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Yorum ekleme
  static Future<void> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Kullanıcı giriş yapmamış');

      // Post bilgilerini al
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post bulunamadı');
      }
      final postData = postDoc.data() as Map<String, dynamic>;
      final postUserId = postData['userId'] as String?;
      if (postUserId == null) {
        throw Exception('Post sahibi bilgisi bulunamadı');
      }

      // Kullanıcı bilgilerini al
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      
      if (userData == null) throw Exception('Kullanıcı bilgileri bulunamadı');

      final comment = Comment(
        id: '', // Firestore tarafından oluşturulacak
        postId: postId,
        userId: user.uid,
        userName: userData['name'] ?? 'Bilinmeyen Kullanıcı',
        userImageUrl: userData['profileImageUrl'],
        content: content,
        timestamp: Timestamp.now(),
        likes: [],
        parentCommentId: parentCommentId,
        replies: [],
      );

      final commentDoc = await _firestore.collection('comments').add(comment.toMap());

      // Yorum bildirimi gönder
      await NotificationService.createCommentNotification(
        postUserId: postUserId,
        postId: postId,
        commentContent: content,
        commentId: commentDoc.id,
      );

      // Post'un yorum sayısını güncelle
      try {
        await _firestore.collection('posts').doc(postId).update({
          'commentCount': FieldValue.increment(1),
        });
        print('✅ Post yorum sayısı güncellendi');
      } catch (e) {
        print('⚠️ Post yorum sayısı güncellenemedi, yeni alan oluşturuluyor: $e');
        // Eğer commentCount alanı yoksa, önce mevcut yorum sayısını hesapla
        final commentsSnapshot = await _firestore
            .collection('comments')
            .where('postId', isEqualTo: postId)
            .where('isDeleted', isEqualTo: false)
            .get();
        
        final commentCount = commentsSnapshot.docs.length;
        
        await _firestore.collection('posts').doc(postId).update({
          'commentCount': commentCount,
        });
        print('✅ Post yorum sayısı yeniden hesaplandı: $commentCount');
      }

      print('✅ Yorum başarıyla eklendi');
    } catch (e) {
      print('❌ Yorum ekleme hatası: $e');
      rethrow;
    }
  }

  // Post'un yorumlarını yükleme
  static Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final comments = <Comment>[];
      
      for (final doc in snapshot.docs) {
        final comment = Comment.fromMap(doc.id, doc.data());
        
        // Sadece ana yorumları al (parentCommentId null olanlar)
        if (comment.parentCommentId == null) {
          // Yanıtları yükle
          final replies = await _getReplies(doc.id);
          final commentWithReplies = comment.copyWith(replies: replies);
          comments.add(commentWithReplies);
        }
      }
      
      // Manuel olarak timestamp'e göre sırala
      comments.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return comments;
    });
  }

  // Yanıtları yükleme
  static Future<List<Comment>> _getReplies(String parentCommentId) async {
    try {
      final snapshot = await _firestore
          .collection('comments')
          .where('parentCommentId', isEqualTo: parentCommentId)
          .where('isDeleted', isEqualTo: false)
          .get();

      final replies = snapshot.docs
          .map((doc) => Comment.fromMap(doc.id, doc.data()))
          .toList();
      
      // Manuel olarak timestamp'e göre sırala
      replies.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return replies;
    } catch (e) {
      print('❌ Yanıt yükleme hatası: $e');
      return [];
    }
  }

  // Yorum beğenme/beğenmeme
  static Future<void> toggleLike(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Kullanıcı giriş yapmamış');

      final commentRef = _firestore.collection('comments').doc(commentId);
      final commentDoc = await commentRef.get();
      
      if (!commentDoc.exists) throw Exception('Yorum bulunamadı');

      final likes = List<String>.from(commentDoc.data()?['likes'] ?? []);
      
      if (likes.contains(user.uid)) {
        likes.remove(user.uid);
      } else {
        likes.add(user.uid);
      }

      await commentRef.update({'likes': likes});
      print('✅ Yorum beğeni durumu güncellendi');
    } catch (e) {
      print('❌ Yorum beğeni hatası: $e');
      rethrow;
    }
  }

  // Yorum silme
  static Future<void> deleteComment(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Kullanıcı giriş yapmamış');

      final commentRef = _firestore.collection('comments').doc(commentId);
      final commentDoc = await commentRef.get();
      
      if (!commentDoc.exists) throw Exception('Yorum bulunamadı');

      final commentData = commentDoc.data();
      if (commentData?['userId'] != user.uid) {
        throw Exception('Bu yorumu silme yetkiniz yok');
      }

      // Yorumu sil (soft delete)
      await commentRef.update({'isDeleted': true});

      // Post'un yorum sayısını güncelle
      final postId = commentData?['postId'];
      if (postId != null) {
        try {
          await _firestore.collection('posts').doc(postId).update({
            'commentCount': FieldValue.increment(-1),
          });
          print('✅ Post yorum sayısı azaltıldı');
        } catch (e) {
          print('⚠️ Post yorum sayısı güncellenemedi, yeniden hesaplanıyor: $e');
          // Eğer commentCount alanı yoksa, yeniden hesapla
          final commentsSnapshot = await _firestore
              .collection('comments')
              .where('postId', isEqualTo: postId)
              .where('isDeleted', isEqualTo: false)
              .get();
          
          final commentCount = commentsSnapshot.docs.length;
          
          await _firestore.collection('posts').doc(postId).update({
            'commentCount': commentCount,
          });
          print('✅ Post yorum sayısı yeniden hesaplandı: $commentCount');
        }
      }

      print('✅ Yorum başarıyla silindi');
    } catch (e) {
      print('❌ Yorum silme hatası: $e');
      rethrow;
    }
  }

  // Yorum düzenleme
  static Future<void> editComment(String commentId, String newContent) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Kullanıcı giriş yapmamış');

      final commentRef = _firestore.collection('comments').doc(commentId);
      final commentDoc = await commentRef.get();
      
      if (!commentDoc.exists) throw Exception('Yorum bulunamadı');

      final commentData = commentDoc.data();
      if (commentData?['userId'] != user.uid) {
        throw Exception('Bu yorumu düzenleme yetkiniz yok');
      }

      await commentRef.update({
        'content': newContent,
        'edited': true,
        'editedAt': Timestamp.now(),
      });

      print('✅ Yorum başarıyla düzenlendi');
    } catch (e) {
      print('❌ Yorum düzenleme hatası: $e');
      rethrow;
    }
  }

  // Tüm post'ların yorum sayısını güncelle (bir kez çalıştırılacak)
  static Future<void> updateAllPostCommentCounts() async {
    try {
      print('🔄 Tüm post\'ların yorum sayıları güncelleniyor...');
      
      final postsSnapshot = await _firestore.collection('posts').get();
      
      for (final postDoc in postsSnapshot.docs) {
        final postId = postDoc.id;
        
        // Bu post'a ait yorum sayısını hesapla
        final commentsSnapshot = await _firestore
            .collection('comments')
            .where('postId', isEqualTo: postId)
            .where('isDeleted', isEqualTo: false)
            .get();
        
        final commentCount = commentsSnapshot.docs.length;
        
        // Post'u güncelle
        await _firestore.collection('posts').doc(postId).update({
          'commentCount': commentCount,
        });
        
        print('✅ Post $postId: $commentCount yorum');
      }
      
      print('✅ Tüm post\'ların yorum sayıları güncellendi');
    } catch (e) {
      print('❌ Post yorum sayıları güncellenirken hata: $e');
      rethrow;
    }
  }
} 