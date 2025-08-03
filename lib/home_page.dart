import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'messages_page.dart';
import 'user_profile_page.dart';
import 'profile_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'webrtc_call_page.dart';
import 'webrtc_call_service.dart';
import 'matching_service.dart';
import 'matching_waiting_page.dart';
import 'online_users_page.dart';
import 'settings_page.dart';
import 'theme_service.dart';
import 'social_page.dart';
import 'notifications_page.dart';
import 'services/notification_service.dart';
import 'search_page.dart';
import 'most_active_users_page.dart';
import 'new_users_page.dart';
import 'nearby_users_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
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
    _tabController = TabController(length: 6, vsync: this);
    _updateLastActive();
    _activeTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateLastActive());
    _listenForIncomingCalls();
    _listenForUnreadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
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


  void _listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _callListener = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'calling')
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

      if (mounted) {
        setState(() {
          _unreadMessageCount = uniqueSenders.length;
        });
      }
    });
  }

  void _showIncomingCallDialog(String callId, String callerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Gelen Arama'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
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

  Widget _buildConnectTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            // Ana Bağlan butonu
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                    spreadRadius: 0,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    print('🔘 Bağlan butonuna basıldı!');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔘 Bağlan butonuna basıldı!')),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MatchingWaitingPage()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSecondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.shuffle,
                            color: Theme.of(context).colorScheme.onSecondary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Bağlan',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Açıklama metni
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.people_alt,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rastgele Bir Kişiyle Bağlan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Yeni insanlarla tanış, sohbet et ve arkadaşlık kur. Bağlan butonuna basarak rastgele birisiyle eşleşebilirsin.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, isDarkMode, child) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.shuffle), text: 'Bağlan'),
                Tab(icon: Icon(Icons.forum), text: 'Sosyal'),
                Tab(icon: Icon(Icons.people_rounded), text: 'Çevrimiçi'),
                Tab(icon: Icon(Icons.trending_up), text: 'En Aktif'),
                Tab(icon: Icon(Icons.person_add), text: 'Yeni'),
                Tab(icon: Icon(Icons.location_on), text: 'Yakınım'),
              ],
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
              indicatorColor: Theme.of(context).colorScheme.onPrimary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
            actions: [
              // Arama butonu
              IconButton(
                icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onPrimary),
                tooltip: 'Ara',
                onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                      builder: (context) => const SearchPage(),
                    ),
                  );
                },
              ),
              // Bildirim butonu
              StreamBuilder<int>(
                stream: NotificationService.getUnreadCount(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimary),
                        tooltip: 'Bildirimler',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
                                IconButton(
                icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
                tooltip: 'Ayarlar',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                          ),
              IconButton(
                icon: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary),
                tooltip: 'Profil',
                onPressed: () {
                  final myId = FirebaseAuth.instance.currentUser?.uid;
                  if (myId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  }
                },
              ),
              Stack(
                    children: [
                  IconButton(
                    icon: Icon(Icons.message, color: Theme.of(context).colorScheme.onPrimary),
                    tooltip: 'Mesajlar',
                        onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesPage()));
                        },
                      ),
                  if (_unreadMessageCount > 0)
                        Positioned(
                      right: 8,
                      top: 8,
                          child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                            ),
                            child: Text(
                          _unreadMessageCount.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Bağlan
              _buildConnectTab(),
              // Tab 2: Sosyal
              const SocialPage(),
              // Tab 3: Çevrimiçi Kullanıcılar
              const OnlineUsersPage(),
              // Tab 4: En Aktif Kullanıcılar
              const MostActiveUsersPage(),
              // Tab 5: Yeni Kullanıcılar
              const NewUsersPage(),
              // Tab 6: Yakınımdakiler
              const NearbyUsersPage(),
            ],
          ),
        );
      },
    );
  }
}