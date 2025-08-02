import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'webrtc_call_page.dart';
import 'notification_service.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatPage({
    Key? key,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Chat ID'sini oluştur (her iki kullanıcı için aynı olacak)
  String _generateChatId() {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final receiverId = widget.receiverId;
    
    // Alfabetik sıraya göre sırala ki her iki kullanıcı için aynı ID olsun
    final sortedIds = [currentUserId, receiverId]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    
    try {
      _chatId = _generateChatId();
      
      // Bu sohbetteki okunmamış mesajları okundu olarak işaretle
      await _markMessagesAsRead();
      
    } catch (e) {
      print('Chat başlatma hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Bu sohbetteki, karşı tarafın gönderdiği okunmamış mesajları bul
      final unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: _chatId)
          .where('senderId', isEqualTo: widget.receiverId)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update ile hepsini okundu olarak işaretle
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Mesajları okundu işaretleme hatası: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _startVoiceCall() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Chat araması için özel format kullan (eşleştirme aramasından ayırt etmek için)
    final callId = 'chat_${currentUser.uid}_${widget.receiverId}_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      // Caller'ın adını al
      final callerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final callerData = callerDoc.data() as Map<String, dynamic>?;
      final callerName = callerData?['name'] ?? 'Bilinmeyen Kullanıcı';
      
      // Karşı tarafa bildirim gönder
      await NotificationService.sendCallNotification(
        receiverId: widget.receiverId,
        callerName: callerName,
        callId: callId,
        callType: 'voice',
        callerId: currentUser.uid,
      );
      
      // Arama sayfasına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebRTCCallPage(
            callId: callId,
            isCaller: true,
          ),
        ),
      );
    } catch (e) {
      print('Arama başlatma hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arama başlatılamadı: $e')),
      );
    }
  }

  void _startVideoCall() {
    // Şimdilik sesli arama olarak başlat (video call henüz implement edilmedi)
    _startVoiceCall();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('messages').add({
        'senderId': user.uid,
        'receiverId': widget.receiverId,
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'participants': [user.uid, widget.receiverId],
        'chatId': _chatId, // Chat ID'sini ekle
        'deletedFor': [],
      });

      // Karşı tarafa bildirim gönder
      await _sendMessageNotification(message);

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessageNotification(String message) async {
    try {
      print('📱 Mesaj bildirimi gönderiliyor...');
      print('📱 Alıcı ID: ${widget.receiverId}');
      print('📱 Alıcı adı: ${widget.receiverName}');
      print('📱 Mesaj: $message');
      
      // Karşı tarafın FCM token'ını al
      final receiverDoc = await _firestore.collection('users').doc(widget.receiverId).get();
      if (receiverDoc.exists) {
        final receiverData = receiverDoc.data() as Map<String, dynamic>;
        final fcmToken = receiverData['fcmToken'];
        
        print('📱 Alıcı verileri: $receiverData');
        print('📱 FCM Token: ${fcmToken != null ? fcmToken.substring(0, 20) + '...' : 'null'}');
        
        if (fcmToken != null && fcmToken.isNotEmpty) {
          // Gönderen kişinin adını al
          final senderDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
          final senderName = senderDoc.exists ? (senderDoc.data() as Map<String, dynamic>)['name'] ?? 'Bilinmeyen' : 'Bilinmeyen';
          
          print('📱 Gönderen adı: $senderName');
          
          // Bildirim gönder
          await NotificationService.sendPushNotification(
            token: fcmToken,
            title: senderName, // Gönderen kişinin adı
            body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
            data: {
              'type': 'message',
              'senderId': _auth.currentUser!.uid,
              'chatId': _chatId,
              'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          );
          print('✅ Mesaj bildirimi gönderildi: $senderName -> ${widget.receiverName}');
        } else {
          print('❌ Alıcının FCM token\'ı bulunamadı');
        }
      } else {
        print('❌ Alıcı kullanıcısı bulunamadı: ${widget.receiverId}');
      }
    } catch (e) {
      print('❌ Mesaj bildirimi gönderilemedi: $e');
      print('❌ Hata detayı: ${e.toString()}');
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.receiverName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Çevrimiçi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
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
              icon: Icon(Icons.call, color: Colors.white, size: 24),
              onPressed: () => _startVoiceCall(),
              tooltip: 'Sesli Arama',
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.videocam, color: Colors.white, size: 24),
              onPressed: () => _startVideoCall(),
              tooltip: 'Görüntülü Arama',
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white, size: 24),
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    // Profil sayfasına git
                    break;
                  case 'block':
                    // Kullanıcıyı engelle
                    break;
                  case 'clear':
                    // Sohbeti temizle
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text('Profili Görüntüle'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Engelle'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Sohbeti Temizle'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('messages')
                        .where('chatId', isEqualTo: _chatId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text('Hata: ${snapshot.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _initializeChat,
                                child: const Text('Yenile'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data?.docs ?? [];

                      // Client-side'da timestamp'e göre sırala
                      messages.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTimestamp = aData['timestamp'] as Timestamp?;
                        final bTimestamp = bData['timestamp'] as Timestamp?;
                        
                        if (aTimestamp == null && bTimestamp == null) return 0;
                        if (aTimestamp == null) return -1;
                        if (bTimestamp == null) return 1;
                        
                        return aTimestamp.compareTo(bTimestamp);
                      });

                      if (messages.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Henüz mesaj yok',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'İlk mesajı göndererek sohbeti başlatın',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Yeni mesaj geldiğinde otomatik scroll
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data() as Map<String, dynamic>;
                          final isMe = message['senderId'] == _auth.currentUser?.uid;
                          final timestamp = message['timestamp'] as Timestamp?;
                          final time = timestamp != null
                              ? DateFormat('HH:mm').format(timestamp.toDate())
                              : '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey[300],
                                    child: Text(
                                      widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.blue : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20).copyWith(
                                        bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message['text'] ?? '',
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              time,
                                              style: TextStyle(
                                                color: isMe ? Colors.white70 : Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                message['isRead'] == true ? Icons.done_all : Icons.done,
                                                size: 16,
                                                color: message['isRead'] == true ? Colors.white70 : Colors.white54,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.blue[100],
                                    child: const Icon(Icons.person, size: 16, color: Colors.blue),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.deepPurple, size: 24),
                    onPressed: () {
                      // Dosya ekleme fonksiyonu
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.grey.shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple,
                        Colors.deepPurple.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.4),
                        spreadRadius: 0,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 24),
                    onPressed: _isLoading ? null : _sendMessage,
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