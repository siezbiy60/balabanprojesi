import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverUsername;

  const ChatPage({required this.receiverId, required this.receiverUsername, super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      print('Hata: Mesaj boş');
      return;
    }
    final user = _auth.currentUser!;
    print('Mesaj gönderme denemesi - Kullanıcı ID: ${user.uid}, E-posta Doğrulanmış: ${user.emailVerified}, Alıcı ID: ${widget.receiverId}');
    if (!user.emailVerified) {
      print('Hata: E-posta doğrulanmamış, Gönderen: ${user.uid}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen e-postanızı doğrulayın')),
        );
      }
      return;
    }

    // Alıcı ID'nin geçerli olduğunu kontrol et
    if (widget.receiverId.isEmpty) {
      print('Hata: Alıcı ID boş');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geçersiz alıcı.')),
        );
      }
      return;
    }
    final receiverDoc = await _firestore.collection('users').doc(widget.receiverId).get();
    if (!receiverDoc.exists) {
      print('Hata: Alıcı ID mevcut değil: ${widget.receiverId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alıcı bulunamadı.')),
        );
      }
      return;
    }

    try {
      final messageData = {
        'senderId': user.uid,
        'receiverId': widget.receiverId,
        'text': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'deletedFor': [],
        'participants': [user.uid, widget.receiverId], // Add this line
      };
      print('Mesaj verisi: $messageData');
      final docRef = await _firestore.collection('messages').add(messageData);
      print('Mesaj eklendi, ID: ${docRef.id}, Gönderen: ${user.uid}, Alıcı: ${widget.receiverId}');
      _messageController.clear();

      // Mesajın hemen görünmesi için akışı yenile
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Mesaj gönderme hatası: $e, Gönderen: ${user.uid}, Alıcı: ${widget.receiverId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
      }
    }
  }

  Future<void> _deleteChatForCurrentUser() async {
    try {
      final user = _auth.currentUser!;
      final sentMessages = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: user.uid)
          .where('receiverId', isEqualTo: widget.receiverId)
          .get();

      final receivedMessages = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: widget.receiverId)
          .where('receiverId', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (var doc in sentMessages.docs) {
        final data = doc.data();
        final deletedFor = List<String>.from(data['deletedFor'] ?? []);
        if (!deletedFor.contains(user.uid)) {
          deletedFor.add(user.uid);
          batch.update(doc.reference, {'deletedFor': deletedFor});
        }
      }
      for (var doc in receivedMessages.docs) {
        final data = doc.data();
        final deletedFor = List<String>.from(data['deletedFor'] ?? []);
        if (!deletedFor.contains(user.uid)) {
          deletedFor.add(user.uid);
          batch.update(doc.reference, {'deletedFor': deletedFor});
        }
      }

      await batch.commit();
      print('Sohbet ${user.uid} için silindi');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Sohbet silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet silinemedi: $e')),
        );
      }
    }
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      final user = _auth.currentUser!;
      if (!user.emailVerified) {
        print('E-posta doğrulanmamış, mesaj okundu işareti güncellenemez');
        return;
      }

      final messageDoc = await _firestore.collection('messages').doc(messageId).get();
      final messageData = messageDoc.data() as Map<String, dynamic>?;
      if (messageData == null) {
        print('Hata: Mesaj verisi null, ID: $messageId');
        return;
      }
      final receiverId = messageData['receiverId'] as String?;
      final isRead = messageData['isRead'] as bool? ?? false;
      print('Okundu kontrolü - Kullanıcı UID: ${user.uid}, Alıcı ID: $receiverId, Okundu: $isRead');
      if (receiverId == user.uid && !isRead) {
        await _firestore.collection('messages').doc(messageId).update({'isRead': true});
        print('Mesaj okundu olarak işaretlendi: $messageId');
      }
    } catch (e) {
      print('Mesaj okundu hatası: $e');
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getMessagesStream() {
    final user = _auth.currentUser!;
    print('Mesaj akışı başlatılıyor - Kullanıcı: ${user.uid}, Alıcı: ${widget.receiverId}');
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: user.uid)  // Change this line
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Mesaj akışı - Çekilen belgeler: ${snapshot.docs.length}');
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final deletedFor = List<String>.from(data['deletedFor'] ?? []);
        final participants = List<String>.from(data['participants'] ?? []);

        // Filter for this specific conversation
        final isRelevant = participants.contains(widget.receiverId);
        final isNotDeleted = !deletedFor.contains(user.uid);

        return isRelevant && isNotDeleted;
      }).toList();
    }).handleError((error) {
      print('Mesaj akışı hatası: $error');
    });
  }
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    print('ChatPage: Başlatıldı - Kullanıcı ID: ${user.uid}, Alıcı ID: ${widget.receiverId}, '
        'E-posta Doğrulanmış: ${user.emailVerified}, Alıcı Kullanıcı Adı: ${widget.receiverUsername}');

    if (!user.emailVerified) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Hata'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Lütfen e-postanızı doğrulayın.'),
              ElevatedButton(
                onPressed: () async {
                  await user.sendEmailVerification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Doğrulama linki gönderildi')),
                    );
                  }
                },
                child: Text('Doğrulama Linki Gönder'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.receiverUsername.isNotEmpty ? widget.receiverUsername : 'Bilinmeyen Kullanıcı',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Sohbeti Sil'),
                      content: Text('Bu sohbeti silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
                      actions: [
                        TextButton(
                          child: Text('İptal'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        TextButton(
                          child: Text('Sil', style: TextStyle(color: Colors.red)),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _deleteChatForCurrentUser();
                          },
                        ),
                      ],
                    );
                  },
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sohbeti Sil'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: getMessagesStream(),
              initialData: [], // Boş liste ile başlat
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  print('ChatPage: Veri yükleniyor...');
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('ChatPage hatası: ${snapshot.error.toString()}');
                  return Center(child: Text('Hata: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('ChatPage: Mesaj bulunamadı');
                  return Center(child: Text('Mesaj bulunamadı.'));
                }

                final messages = snapshot.data!;
                print('ChatPage: Çekilen mesaj sayısı: ${messages.length}');
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data();
                    final messageId = messages[index].id;
                    final senderId = messageData['senderId'] as String?;
                    final text = messageData['text'] as String?;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final isRead = messageData['isRead'] as bool? ?? false;
                    final isSentByMe = senderId == user.uid;

                    if (senderId == null || text == null || timestamp == null) {
                      print('Hata: Eksik veri, mesaj ID: $messageId, Veri: $messageData');
                      return const SizedBox.shrink();
                    }

                    if (!isSentByMe && !isRead && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markMessageAsRead(messageId);
                      });
                    }

                    return Align(
                      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isSentByMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, top: 4),
                              child: CircleAvatar(
                                radius: 16,
                                child: Text(
                                  widget.receiverUsername.isNotEmpty
                                      ? widget.receiverUsername[0].toUpperCase()
                                      : 'B',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                ),
                              ),
                            ),
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSentByMe ? Theme.of(context).primaryColor : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isSentByMe
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat('HH:mm').format(timestamp.toDate()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSentByMe
                                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                                              : Colors.grey,
                                        ),
                                      ),
                                      if (isSentByMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isRead ? Icons.done_all : Icons.done,
                                          size: 12,
                                          color: isRead
                                              ? Colors.blue
                                              : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}