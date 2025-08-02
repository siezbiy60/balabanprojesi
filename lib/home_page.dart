import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'messages_page.dart';
import 'user_profile_page.dart';
import 'profile_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'notification_service.dart';
import 'webrtc_call_page.dart';
import 'webrtc_call_service.dart';
import 'matching_service.dart';
import 'matching_waiting_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WebRTCCallService? _callService;
  StreamSubscription<QuerySnapshot>? _callListener;
  String? _incomingCallId;
  String? _incomingCallerId;
  String? _incomingCallerName;
  bool _isIncomingCallDialogVisible = false;
  StreamSubscription<DocumentSnapshot>? _matchListener;
  String? _currentCallId;
  bool _isMatching = false;
  Timer? _activeTimer;
  int _unreadMessageCount = 0;
  StreamSubscription<QuerySnapshot>? _unreadMessagesListener;

  @override
  void initState() {
    super.initState();
    _updateLastActive();
    _activeTimer = Timer.periodic(Duration(minutes: 1), (_) => _updateLastActive());
    _listenForIncomingCalls();
    _listenForUnreadMessages();
  }

  @override
  void dispose() {
    _callListener?.cancel();
    _matchListener?.cancel();
    _activeTimer?.cancel();
    _unreadMessagesListener?.cancel();
    super.dispose();
  }

  void _updateLastActive() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid)
        .update({'lastActive': FieldValue.serverTimestamp()});
    }
  }

  // Test bildirimi gönder
  Future<void> _testNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Kendi FCM token'ını al
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'];
        
        if (fcmToken != null && fcmToken.isNotEmpty) {
          print('🧪 Test bildirimi gönderiliyor...');
          print('🧪 Token: ${fcmToken.substring(0, 20)}...');
          
          await NotificationService.sendPushNotification(
            token: fcmToken,
            title: 'Test Bildirimi',
            body: 'Bu bir test mesajıdır! ${DateTime.now().toString()}',
            data: {
              'type': 'test',
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🧪 Test bildirimi gönderildi!')),
          );
        } else {
          print('❌ FCM token bulunamadı');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ FCM token bulunamadı')),
          );
        }
      }
    } catch (e) {
      print('❌ Test bildirimi hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Test hatası: $e')),
      );
    }
  }

  // Okunmamış mesajları dinle
  void _listenForUnreadMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _unreadMessagesListener = FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      // Benzersiz gönderen sayısını hesapla
      final uniqueSenders = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final senderId = data['senderId'] as String?;
        if (senderId != null) {
          uniqueSenders.add(senderId);
        }
      }
      
      setState(() {
        _unreadMessageCount = uniqueSenders.length;
      });
    });
  }

  // Gelen aramaları dinle (calls koleksiyonu üzerinden)
  void _listenForIncomingCalls() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _callListener = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && !_isIncomingCallDialogVisible) {
        final callDoc = snapshot.docs.first;
        final data = callDoc.data() as Map<String, dynamic>;
        String callerName = "Bilinmeyen";
        try {
          final callerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['callerId'])
              .get();
          if (callerDoc.exists) {
            final callerData = callerDoc.data() as Map<String, dynamic>;
            callerName = callerData['username'] ?? "Bilinmeyen";
          }
        } catch (e) {
          print('Arayan kişi bilgisi alınamadı: $e');
        }
        setState(() {
          _incomingCallId = callDoc.id;
          _incomingCallerId = data['callerId'];
          _incomingCallerName = callerName;
          _isIncomingCallDialogVisible = true;
        });
        _showIncomingCallDialog();
      } else if (snapshot.docs.isEmpty) {
        setState(() {
          _isIncomingCallDialogVisible = false;
          _incomingCallId = null;
          _incomingCallerId = null;
          _incomingCallerName = null;
        });
      }
    });
  }

  // Gelen arama dialog'unu göster (WebRTC ile)
  void _showIncomingCallDialog() {
    if (_incomingCallId == null) return;
    final callId = _incomingCallId!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Gelen Arama'),
        content: Text('${_incomingCallerName ?? "Bilinmeyen"} seni arıyor'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _isIncomingCallDialogVisible = false;
              });
              Navigator.of(context).pop();
              // WebRTC arama ekranına yönlendir
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WebRTCCallPage(
                    callId: callId,
                    isCaller: false,
                  ),
                ),
              );
            },
            child: const Text('Kabul Et'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          TextButton(
            onPressed: () async {
              // Çağrıyı reddetmek için dokümanı sil
              await FirebaseFirestore.instance.collection('calls').doc(callId).delete();
              setState(() {
                _isIncomingCallDialogVisible = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  void _startMatching() async {
    setState(() { _isMatching = true; });
    final callId = await MatchingService.findMatchAndStartCall();
    if (callId != null) {
      _goToCall(callId, true);
    } else {
      _listenForMatch();
    }
  }

  void _listenForMatch() {
    _matchListener?.cancel();
    _matchListener = MatchingService.listenForMatch().listen((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['callId'] != null && data['matchedWith'] != null) {
        _goToCall(data['callId'], true);
        _matchListener?.cancel();
        setState(() { _isMatching = false; });
      }
    });
  }

  void _leaveQueueAndRematch() async {
    await MatchingService.leaveQueue();
    _startMatching();
  }

  void _goToCall(String callId, bool isCaller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebRTCCallPage(callId: callId, isCaller: isCaller),
      ),
    );
  }

  // Test amaçlı push bildirim gönderme fonksiyonu
  Future<void> sendTestNotification(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) => doc['fcmToken'] as String?);
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FCM token bulunamadı!')));
      return;
    }
    const url = 'https://us-central1-balabanproje.cloudfunctions.net/sendPushNotificationHttp';  
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'title': 'Test Bildirimi',
        'body': 'Bu bir test mesajıdır!',
      }),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backend response: ${response.body}')));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            tooltip: 'Profil',
            onPressed: () {
              final myId = FirebaseAuth.instance.currentUser?.uid;
              if (myId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(),
                  ),
                );
              }
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.message, color: Colors.white),
                tooltip: 'Mesajlar',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MessagesPage()));
                },
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadMessageCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.deepPurple.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          // Bağlan butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                icon: Icon(Icons.shuffle, size: 32),
                label: Text('Bağlan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  print('🔘 Bağlan butonuna basıldı!');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🔘 Bağlan butonuna basıldı!')),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MatchingWaitingPage()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Test butonları (sadece debug için)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.notifications, size: 20),
                    label: Text('Bildirim Test Et', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _testNotification,
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Kullanıcı listesi başlığı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.deepPurple, size: 28),
                const SizedBox(width: 8),
                Text('Çevrim içi Kullanıcılar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Kullanıcı listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hata:  {snapshot.error.toString()}'));
                }
                final now = DateTime.now();
                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
                  if (lastActive == null) return false;
                  return now.difference(lastActive).inMinutes < 2;
                }).toList();
                if (users.isEmpty) {
                  return const Center(child: Text('Çevrim içi kullanıcı yok.'));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    if (userId == user.uid) return const SizedBox.shrink();
                    
                    // Debug bilgisi
                    print('Kullanıcı verileri: $userData');
                    
                    // Farklı alan adlarını dene - name alanını öncelikli yap
                    final username = userData['name'] as String? ?? 
                                   userData['username'] as String? ?? 
                                   userData['displayName'] as String? ?? 
                                   'Bilinmiyor';
                    final city = userData['city'] as String? ?? 'Bilinmiyor';
                    final profileImageUrl = userData['profileImageUrl'] as String?;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(userId: userId),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              profileImageUrl != null && profileImageUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        profileImageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.deepPurple.shade200,
                                            child: const Icon(Icons.person, color: Colors.white),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.deepPurple.shade200,
                                            child: const CircularProgressIndicator(),
                                          );
                                        },
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.deepPurple.shade200,
                                      child: const Icon(Icons.person, color: Colors.white),
                                    ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text('@${userData['username'] ?? 'nickname'}', style: TextStyle(color: Colors.blue[600], fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('Şehir: $city', style: TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.green, size: 16),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: Icon(Icons.message, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatPage(
                                            receiverId: userId,
                                            receiverName: username,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'Mesaj Gönder',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}