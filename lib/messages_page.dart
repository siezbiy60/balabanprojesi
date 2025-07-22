import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';

class MessagesPage extends StatefulWidget {
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

    _messagesStream = _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .orderBy('timestamp', descending: true)
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Giriş yapılmamış'),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: Text('Giriş Yap'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mesajlar', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _messagesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text('Hata oluştu: ${snapshot.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMessages,
                    child: Text('Yenile'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Henüz mesaj yok.'));
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
                final messageTimestamp = data['timestamp'] as Timestamp;
                final existingMessage = latestMessages[otherUserId];
                final existingTimestamp = existingMessage?.get('timestamp') as Timestamp?;

                if (existingTimestamp == null || messageTimestamp.compareTo(existingTimestamp) > 0) {
                  latestMessages[otherUserId] = message;
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
              final otherUserId = entry.key;
              final lastMessage = entry.value.data() as Map<String, dynamic>;

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

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? Text(username.isNotEmpty ? username[0] : '?')
                            : null,
                      ),
                      title: Text(username),
                      subtitle: Text(
                        isSentByMe ? 'Sen: $messageText' : messageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (timestamp != null)
                            Text(
                              DateFormat('HH:mm').format(timestamp.toDate()),
                              style: TextStyle(fontSize: 12),
                            ),
                          if (!isRead && !isSentByMe)
                            Icon(Icons.circle, color: Colors.blue, size: 12),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              receiverId: otherUserId,
                              receiverUsername: username,
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