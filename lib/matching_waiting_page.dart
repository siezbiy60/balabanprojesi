import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'matching_service.dart';
import 'webrtc_call_page.dart';

class MatchingWaitingPage extends StatefulWidget {
  const MatchingWaitingPage({Key? key}) : super(key: key);

  @override
  State<MatchingWaitingPage> createState() => _MatchingWaitingPageState();
}

class _MatchingWaitingPageState extends State<MatchingWaitingPage> with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _matchListener;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isCancelled = false;
  bool _isInitialized = false;
  Timer? _activityTimer; // Aktivite güncellemesi için timer

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 2))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // İlk kez çağrıldığında eşleşme işlemini başlat
    if (!_isCancelled && !_isInitialized) {
      _isInitialized = true;
      _listenForMatch();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _matchListener?.cancel();
    _activityTimer?.cancel(); // Timer'ı iptal et
    
    // Kullanıcı sayfadan çıktığında kuyruktan çıkar
    if (!_isCancelled) {
      MatchingService.leaveQueue();
      print('🚪 MatchingWaitingPage: Kullanıcı sayfadan çıktı, kuyruktan çıkarıldı');
    }
    
    super.dispose();
  }

  void _listenForMatch() async {
    if (!mounted) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ MatchingWaitingPage: Kullanıcı oturum açmamış!');
      return;
    }
    
    print('🚀 MatchingWaitingPage: Eşleşme başlatılıyor...');
    
    // Önce eşleşme aramaya başla
    final callId = await MatchingService.findMatchAndStartCall();
    print('📞 MatchingWaitingPage: findMatchAndStartCall sonucu: $callId');
    
    // Aktivite güncellemesi için timer başlat (her 30 saniyede bir)
    _startActivityTimer();
    
    if (callId != null && !_isCancelled && mounted) {
      // Hemen eşleşme bulundu - bu kullanıcı arayan (caller)
      print('🎯 MatchingWaitingPage: Hemen eşleşme bulundu! WebRTCCallPage açılıyor...');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WebRTCCallPage(callId: callId, isCaller: true),
          ),
        );
      }
      return;
    }
    
    // Eşleşme bulunamadıysa dinlemeye başla
    print('👂 MatchingWaitingPage: Eşleşme dinlemeye başlanıyor...');
    _matchListener = MatchingService.listenForMatch().listen((doc) {
      if (_isCancelled || !mounted) {
        print('❌ MatchingWaitingPage: İptal edildi veya widget dispose edildi, dinleme durduruldu');
        return;
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      print('📡 MatchingWaitingPage: Firestore güncellemesi alındı: $data');
      
      if (data != null) {
        print('📊 MatchingWaitingPage: Data analizi:');
        print('  - callId: ${data['callId']}');
        print('  - matchedWith: ${data['matchedWith']}');
        print('  - isCaller: ${data['isCaller']}');
        print('  - _isCancelled: $_isCancelled');
      }
      
      if (!_isCancelled && mounted && data != null && data['callId'] != null && data['matchedWith'] != null) {
        final isCaller = data['isCaller'] ?? true; // Varsayılan olarak true
        print('🎯 MatchingWaitingPage: Eşleşme bulundu! CallId: ${data['callId']}, isCaller: $isCaller');
        print('🚀 MatchingWaitingPage: WebRTCCallPage açılıyor...');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🎯 Eşleşme bulundu! CallId: ${data['callId']}, isCaller: $isCaller')),
          );
        }
        
        try {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => WebRTCCallPage(callId: data['callId'], isCaller: isCaller),
              ),
            );
            print('✅ MatchingWaitingPage: WebRTCCallPage başarıyla açıldı');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ WebRTCCallPage başarıyla açıldı')),
              );
            }
            _matchListener?.cancel();
          }
        } catch (e) {
          print('❌ MatchingWaitingPage: WebRTCCallPage açma hatası: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ WebRTCCallPage açma hatası: $e')),
            );
          }
        }
      } else {
        print('⏳ MatchingWaitingPage: Eşleşme henüz tamamlanmadı veya veri eksik');
      }
    });
  }

  void _cancelMatching() async {
    setState(() { _isCancelled = true; });
    await _matchListener?.cancel();
    await MatchingService.leaveQueue();
    if (mounted) Navigator.of(context).maybePop();
  }

  /// Kullanıcı aktivitesini periyodik olarak güncelle
  void _startActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
      if (_isCancelled || !mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('matching_queue')
              .doc(user.uid)
              .update({
            'lastActivity': FieldValue.serverTimestamp(),
          });
          print('🔄 Kullanıcı aktivitesi güncellendi: ${user.uid}');
        }
      } catch (e) {
        print('❌ Aktivite güncelleme hatası: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Icon(Icons.search, size: 60, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Eşleşme aranıyor...\nLütfen bekleyin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 4),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _cancelMatching,
              icon: Icon(Icons.cancel),
              label: Text('İptal Et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}