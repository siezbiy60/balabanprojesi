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
import 'online_users_page.dart';

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
  List<Map<String, dynamic>> _mostActiveUsers = [];
  bool _isLoadingActiveUsers = true;

  @override
  void initState() {
    super.initState();
    _updateLastActive();
    _activeTimer = Timer.periodic(Duration(minutes: 1), (_) => _updateLastActive());
    _listenForIncomingCalls();
    _listenForUnreadMessages();
    _loadMostActiveUsers();
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



  // En çok aktif kullanıcıları yükle
  Future<void> _loadMostActiveUsers() async {
    try {
      setState(() => _isLoadingActiveUsers = true);
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Son 7 gün içinde aktif olan kullanıcıları al
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastActive', descending: true)
          .limit(10)
          .get();

      final users = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final userData = doc.data();
        // Kendimizi listeden çıkar
        if (doc.id != currentUser.uid) {
          users.add({
            'id': doc.id,
            ...userData,
          });
        }
      }

      setState(() {
        _mostActiveUsers = users;
        _isLoadingActiveUsers = false;
      });
    } catch (e) {
      print('❌ En aktif kullanıcılar yüklenirken hata: $e');
      setState(() => _isLoadingActiveUsers = false);
    }
  }

  void _listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _callListener = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'incoming')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final callId = change.doc.id;
          final callerId = data['callerId'] as String;
          final callerName = data['callerName'] as String? ?? 'Bilinmeyen';

          setState(() {
            _incomingCallId = callId;
            _incomingCallerId = callerId;
            _incomingCallerName = callerName;
            _isIncomingCallDialogVisible = true;
          });

          _showIncomingCallDialog(callId, callerName);
        }
      }
    });
  }

  void _listenForUnreadMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _unreadMessagesListener = FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      // Benzersiz gönderen sayısını hesapla
      final uniqueSenders = <String>{};
      for (final doc in snapshot.docs) {
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

  void _showIncomingCallDialog(String callId, String callerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Gelen Arama'),
        content: Text('$callerName sizi arıyor'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() {
                _isIncomingCallDialogVisible = false;
              });
              
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

  // Mesaj gönderme fonksiyonu
  void _startChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          receiverId: userId,
          receiverName: userName,
        ),
      ),
    );
  }

  // Profil görüntüleme fonksiyonu
  void _viewProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

  // Son aktif zamanı formatla
  String _formatLastActive(Timestamp? timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    final now = DateTime.now();
    final lastActive = timestamp.toDate();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inDays} gün önce';
    }
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
          // Çevrimiçi kullanıcılar butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: Icon(Icons.people_rounded, size: 24),
                label: Text('Çevrimiçi Kullanıcılar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OnlineUsersPage()),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          // En çok aktif kullanıcılar başlığı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.deepPurple, size: 28),
                const SizedBox(width: 8),
                Text('En Aktif Kullanıcılar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // En çok aktif kullanıcılar listesi
          Expanded(
            child: _isLoadingActiveUsers
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Kullanıcılar yükleniyor...',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _mostActiveUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.1),
                                    spreadRadius: 0,
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.deepPurple.shade300,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Henüz aktif kullanıcı yok',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Diğer kullanıcılar aktif olduğunda\nburada görünecekler',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.deepPurple.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMostActiveUsers,
                        color: Colors.deepPurple,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _mostActiveUsers.length,
                          itemBuilder: (context, index) {
                            final user = _mostActiveUsers[index];
                            final userName = user['name'] as String? ?? 'Bilinmeyen Kullanıcı';
                            final userImage = user['profileImageUrl'] as String?;
                            final lastActive = user['lastActive'] as Timestamp?;
                            final city = user['city'] as String? ?? 'Bilinmiyor';

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
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
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 0,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundImage: userImage != null
                                        ? CachedNetworkImageProvider(userImage)
                                        : null,
                                    backgroundColor: userImage == null ? Colors.deepPurple.shade100 : null,
                                    child: userImage == null
                                        ? Text(
                                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple.shade700,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                title: Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepPurple.shade800,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      city,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Son aktif: ${_formatLastActive(lastActive)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.deepPurple,
                                          size: 24,
                                        ),
                                        onPressed: () => _startChat(user['id'], userName),
                                        tooltip: 'Mesaj Gönder',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.person_outline,
                                          color: Colors.deepPurple,
                                          size: 24,
                                        ),
                                        onPressed: () => _viewProfile(user['id']),
                                        tooltip: 'Profili Görüntüle',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}