import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  final ImagePicker _picker = ImagePicker();
  bool _isSendingImage = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _receiverStream => _firestore.collection('users').doc(widget.receiverId).snapshots();

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

    // Mesaj metnini sakla ve hemen temizle
    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final messageData = {
        'senderId': user.uid,
        'receiverId': widget.receiverId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'deletedFor': [],
        'participants': [user.uid, widget.receiverId],
      };
      print('Mesaj verisi: $messageData');
      final docRef = await _firestore.collection('messages').add(messageData);
      print('Mesaj eklendi, ID: ${docRef.id}, Gönderen: ${user.uid}, Alıcı: ${widget.receiverId}');

      // Scroll işlemini StreamBuilder güncellemesinden sonra yap
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
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
        // Hata durumunda mesajı geri yükle
        _messageController.text = messageText;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
      }
    }
  }

  // Fotoğraf seçip yükleme ve mesaj olarak gönderme
  Future<void> _pickAndSendImage() async {
    try {
      final user = _auth.currentUser!;
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (pickedFile == null) return;
      setState(() { _isSendingImage = true; });
      final file = pickedFile;
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('chat_images').child(fileName);
      final uploadTask = await ref.putData(await file.readAsBytes());
      final imageUrl = await ref.getDownloadURL();
      await _firestore.collection('messages').add({
        'senderId': user.uid,
        'receiverId': widget.receiverId,
        'imageUrl': imageUrl,
        'text': '',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'deletedFor': [],
        'participants': [user.uid, widget.receiverId],
      });
      setState(() { _isSendingImage = false; });
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() { _isSendingImage = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf gönderilemedi: $e')),
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
        .where('senderId', whereIn: [user.uid, widget.receiverId])
        .where('receiverId', whereIn: [user.uid, widget.receiverId])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Mesaj akışı - Çekilen belgeler: ${snapshot.docs.length}');
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final deletedFor = List<String>.from(data['deletedFor'] ?? []);
        if (deletedFor.contains(user.uid)) {
          print('Mesaj filtrelendi - ID: ${doc.id}, deletedFor: $deletedFor');
          return false;
        }
        return true;
      }).toList();
    }).handleError((error) {
      print('Mesaj akışı hatası: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    print('Benim ID: ${user.uid}, Sohbet açılan ID: ${widget.receiverId}');
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
        toolbarHeight: 56,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _receiverStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || !(snapshot.data?.exists ?? false)) {
              return Text(
                widget.receiverUsername.isNotEmpty ? widget.receiverUsername : 'Bilinmeyen Kullanıcı',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              );
            }
            String statusText = '';
            bool isOnline = false;
            DateTime? lastSeenTime;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data()!;
              isOnline = data['isOnline'] as bool? ?? false;
              final lastSeen = data['lastSeen'];
              if (lastSeen != null) {
                lastSeenTime = (lastSeen is Timestamp)
                    ? lastSeen.toDate()
                    : DateTime.tryParse(lastSeen.toString());
              }
              if (isOnline && lastSeenTime != null && DateTime.now().difference(lastSeenTime).inMinutes > 1) {
                isOnline = false;
              }
              if (!isOnline && lastSeenTime != null) {
                statusText = 'Son görülme: ' + DateFormat('dd MMM HH:mm', 'tr_TR').format(lastSeenTime);
              }
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    widget.receiverUsername.isNotEmpty ? widget.receiverUsername : 'Bilinmeyen Kullanıcı',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOnline) ...[
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'Çevrim içi',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (statusText.isNotEmpty) ...[
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Çevrim dışı',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.white,
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
                    final imageUrl = messageData['imageUrl'] as String?;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final isRead = messageData['isRead'] as bool? ?? false;
                    final isSentByMe = senderId == user.uid;

                    if (senderId == null || timestamp == null) {
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
                      child: _EditableMessageBubble(
                        isSentByMe: isSentByMe,
                        receiverUsername: widget.receiverUsername,
                        text: text,
                        imageUrl: imageUrl,
                        messageData: messageData,
                        timestamp: timestamp,
                        isRead: isRead,
                        onLongPress: () async {
                          await showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Sadece kendinden sil'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _firestore.collection('messages').doc(messageId).update({
                                          'deletedFor': FieldValue.arrayUnion([user.uid])
                                        });
                                      },
                                    ),
                                    if (isSentByMe)
                                      ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Düzenle'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final controller = TextEditingController(text: text);
                                          final result = await showDialog<String>(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: Text('Mesajı Düzenle'),
                                                content: TextField(
                                                  controller: controller,
                                                  maxLines: null,
                                                  autofocus: true,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: Text('İptal'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context, controller.text.trim());
                                                    },
                                                    child: Text('Kaydet'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (result != null && result.isNotEmpty && result != text) {
                                            await _firestore.collection('messages').doc(messageId).update({
                                              'previousText': text,
                                              'text': result,
                                              'edited': true,
                                            });
                                          }
                                        },
                                      ),
                                    if (isSentByMe)
                                      ListTile(
                                        leading: Icon(Icons.delete_forever, color: Colors.red),
                                        title: Text('Herkesten sil', style: TextStyle(color: Colors.red)),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          await _firestore.collection('messages').doc(messageId).delete();
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
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
                // Fotoğraf ekle butonu
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                    color: Theme.of(context).primaryColor,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _isSendingImage ? null : _pickAndSendImage,
                    tooltip: 'Fotoğraf Gönder',
                  ),
                ),
                const SizedBox(width: 8),
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

// Mesaj balonu için stateful widget: düzenlenmiş mesajlarda tıklayınca eski hali gösterir
class _EditableMessageBubble extends StatefulWidget {
  final bool isSentByMe;
  final String receiverUsername;
  final String? text;
  final String? imageUrl;
  final Map<String, dynamic> messageData;
  final Timestamp? timestamp;
  final bool isRead;
  final VoidCallback onLongPress;
  const _EditableMessageBubble({
    required this.isSentByMe,
    required this.receiverUsername,
    required this.text,
    required this.imageUrl,
    required this.messageData,
    required this.timestamp,
    required this.isRead,
    required this.onLongPress,
    Key? key,
  }) : super(key: key);

  @override
  State<_EditableMessageBubble> createState() => _EditableMessageBubbleState();
}

class _EditableMessageBubbleState extends State<_EditableMessageBubble> {
  bool _showPrevious = false;

  void _togglePrevious() {
    if (widget.messageData['edited'] == true && widget.messageData['previousText'] != null) {
      setState(() {
        _showPrevious = !_showPrevious;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePrevious,
      onLongPress: widget.onLongPress,
      child: Row(
        mainAxisAlignment: widget.isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isSentByMe)
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
                color: widget.isSentByMe ? Theme.of(context).primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: widget.isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.imageUrl!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 220,
                            height: 220,
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 220,
                          height: 220,
                          color: Colors.grey[200],
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      widget.text ?? '',
                      style: TextStyle(
                        color: widget.isSentByMe
                            ? Theme.of(context).colorScheme.onPrimary
                            : Colors.black,
                      ),
                    ),
                    if (widget.messageData['edited'] == true)
                      Text(
                        'düzenlendi',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    if (_showPrevious && widget.messageData['previousText'] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Önceki: ${widget.messageData['previousText']}',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[800]),
                        ),
                      ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.timestamp != null
                            ? DateFormat('HH:mm').format(widget.timestamp!.toDate())
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isSentByMe
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                              : Colors.grey,
                        ),
                      ),
                      if (widget.isSentByMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          widget.isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: widget.isRead
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
  }
}