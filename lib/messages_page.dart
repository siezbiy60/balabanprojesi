import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Geçici olarak orderBy'ı kaldırıyoruz, index aktif olana kadar
    _messagesStream = _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .snapshots();
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.data() as Map<String, dynamic>? ?? {
        'username': 'Bilinmeyen Kullanıcı',
        'profileImageUrl': null
      };
    } catch (e) {
      print('Kullanıcı verisi çekme hatası: $e');
      return {'username': 'Bilinmeyen Kullanıcı', 'profileImageUrl': null};
    }
  }

  // Chat ID'sini oluştur (her iki kullanıcı için aynı olacak)
  String _generateChatId(String currentUserId, String otherUserId) {
    final sortedIds = [currentUserId, otherUserId]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Mesajları okundu olarak işaretle
  Future<void> _markMessagesAsRead(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Bu kullanıcıdan gelen okunmamış mesajları bul ve okundu olarak işaretle
      final unreadMessages = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update ile tüm mesajları güncelle
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      
      print('✅ Mesajlar okundu olarak işaretlendi: $otherUserId');
    } catch (e) {
      print('❌ Mesajları okundu olarak işaretleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Giriş yapılmamış'),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Giriş Yap'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Mesajlar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.search, color: Colors.white, size: 24),
              onPressed: () {
                // Arama fonksiyonu
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Hata oluştu: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMessages,
                    child: const Text('Yenile'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Henüz mesaj yok',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Arkadaşlarınızla sohbet etmeye başlayın',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          // Sohbetleri grupla ve son mesajları bul
          final Map<String, DocumentSnapshot> latestMessages = {};
          final currentUserId = currentUser.uid;

          for (final message in snapshot.data!.docs) {
            try {
              final data = message.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final deletedFor = List<String>.from(data['deletedFor'] ?? []);

              if (deletedFor.contains(currentUserId)) continue;

              final otherUserId = participants.firstWhere(
                    (id) => id != currentUserId,
                orElse: () => '',
              );

              if (otherUserId.isNotEmpty) {
                // ChatId varsa onu kullan, yoksa otherUserId kullan (geriye uyumluluk için)
                final chatId = data['chatId'] as String? ?? otherUserId;
                final messageTimestamp = data['timestamp'] as Timestamp;
                final existingMessage = latestMessages[chatId];
                final existingTimestamp = existingMessage?.get('timestamp') as Timestamp?;

                if (existingTimestamp == null || messageTimestamp.compareTo(existingTimestamp) > 0) {
                  latestMessages[chatId] = message;
                }
              }
            } catch (e) {
              print('Mesaj işleme hatası: $e');
            }
          }

          // Sohbetleri tarihe göre sırala
          final sortedChats = latestMessages.entries.toList()
            ..sort((a, b) {
              final aTimestamp = (a.value.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
              final bTimestamp = (b.value.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
              return bTimestamp.compareTo(aTimestamp);
            });

          return ListView.builder(
            itemCount: sortedChats.length,
            itemBuilder: (context, index) {
              final entry = sortedChats[index];
              final chatId = entry.key;
              final lastMessage = entry.value.data() as Map<String, dynamic>;
              
              // ChatId'den otherUserId'yi çıkar
              final participants = List<String>.from(lastMessage['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => chatId, // Fallback olarak chatId kullan
              );

              final isRead = lastMessage['isRead'] as bool? ?? false;
              final isSentByMe = lastMessage['senderId'] as String == currentUser.uid;
              final messageText = lastMessage['text'] as String? ?? '';
              final timestamp = lastMessage['timestamp'] as Timestamp?;

              return FutureBuilder<Map<String, dynamic>>(
                future: _getUserData(otherUserId),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data ?? {
                    'username': 'Bilinmeyen Kullanıcı',
                    'profileImageUrl': null
                  };
                  final username = userData['username'] as String? ?? 'Bilinmeyen';
                  final profileImageUrl = userData['profileImageUrl'] as String?;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.grey.shade50,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 0,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundImage: profileImageUrl != null
                              ? NetworkImage(profileImageUrl)
                              : null,
                          backgroundColor: profileImageUrl == null ? Colors.blue[100] : null,
                          child: profileImageUrl == null
                              ? Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                )
                              : null,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              DateFormat('HH:mm').format(timestamp.toDate()),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isSentByMe ? 'Sen: $messageText' : messageText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              if (!isRead && !isSentByMe) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      onTap: () async {
                        // Mesajları okundu olarak işaretle
                        await _markMessagesAsRead(otherUserId);
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              receiverId: otherUserId,
                              receiverName: username,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}