import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverUsername;

  const ChatPage({required this.receiverId, required this.receiverUsername, super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    try {
      await _firestore.collection('messages').add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': widget.receiverId,
        'text': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print('Mesaj Firestore’a kaydedildi: ${_messageController.text}');
      _messageController.clear();
      _sendNotification(_messageController.text);
    } catch (e) {
      print('Mesaj gönderme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    }
  }

  void _sendNotification(String message) async {
    // FCM bildirim kodunuzu buraya ekleyin
    try {
      print('Bildirim gönderildi: $message');
    } catch (e) {
      print('Bildirim gönderim hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    print('ChatPage Kullanıcı ID: ${user.uid}, Alıcı ID: ${widget.receiverId}');

    final sentMessagesStream = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: user.uid)
        .where('receiverId', isEqualTo: widget.receiverId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    final receivedMessagesStream = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: user.uid)
        .where('senderId', isEqualTo: widget.receiverId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    final mergedStream = CombineLatestStream.list<QuerySnapshot<Map<String, dynamic>>>([
      sentMessagesStream,
      receivedMessagesStream,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverUsername, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
              stream: mergedStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('ChatPage hatası: ${snapshot.error.toString()}');
                  return Center(child: Text('Hata: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!.every((qs) => qs.docs.isEmpty)) {
                  print('ChatPage: Mesaj bulunamadı');
                  return Center(child: Text('Mesaj bulunamadı.'));
                }

                final messages = snapshot.data!
                    .expand((snapshot) => snapshot.docs)
                    .toList()
                  ..sort((a, b) {
                    final aTimestamp = a.data()['timestamp'] as Timestamp?;
                    final bTimestamp = b.data()['timestamp'] as Timestamp?;
                    if (aTimestamp == null || bTimestamp == null) return 0;
                    return aTimestamp.compareTo(bTimestamp);
                  });

                print('ChatPage: Çekilen mesaj sayısı: ${messages.length}');
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data();
                    final senderId = messageData['senderId'] as String?;
                    final text = messageData['text'] as String?;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    if (senderId == null || text == null) {
                      print('Eksik veri: $messageData');
                      return const SizedBox.shrink();
                    }
                    final isSentByMe = senderId == user.uid;

                    if (!isSentByMe && !(messageData['isRead'] ?? false)) {
                      _firestore.collection('messages').doc(messages[index].id).update({'isRead': true});
                      print('Mesaj okundu olarak işaretlendi: ${messages[index].id}');
                    }

                    return Align(
                      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSentByMe ? Theme.of(context).primaryColor : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: isSentByMe ? Theme.of(context).colorScheme.onPrimary : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : 'Bilinmiyor',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSentByMe ? Theme.of(context).colorScheme.onPrimary : Colors.grey,
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
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}