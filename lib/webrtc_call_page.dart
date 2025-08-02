import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_call_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'matching_service.dart';

class WebRTCCallPage extends StatefulWidget {
  final String callId;
  final bool isCaller;
  const WebRTCCallPage({Key? key, required this.callId, required this.isCaller}) : super(key: key);

  @override
  State<WebRTCCallPage> createState() => _WebRTCCallPageState();
}

class _WebRTCCallPageState extends State<WebRTCCallPage> {
  final WebRTCCallService _callService = WebRTCCallService();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _micEnabled = true;
  bool _speakerOn = false;
  String _status = 'Bağlanıyor...';
  int _callSeconds = 0;
  Timer? _callTimer;
  
  // Karşı tarafın bilgileri için
  Map<String, dynamic>? _otherUserData;
  String _otherUserName = 'Bilinmeyen Kullanıcı';
  String? _otherUserProfileImage;
  bool _isLoadingUserData = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _startOrAnswerCall();
    _listenForRemoteMute();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.endCall();
    _callTimer?.cancel();
    
    super.dispose();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _startOrAnswerCall() async {
    _callService.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {
        _status = 'Bağlantı kuruldu';
      });
      // Sadece bağlantı kurulduğunda sayacı başlat
      _startCallTimer();
    };
    
    // Diğer kullanıcı aramayı kapattığında
    _callService.onCallEnded = () {
      setState(() {
        _status = 'Diğer kullanıcı aramayı sonlandırdı';
      });
      _stopCallTimer();
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    };
    
    // Eşleştirme araması mı yoksa normal arama mı kontrol et
    final isMatchingCall = widget.callId.startsWith('chat_') ? false : 
                          (widget.callId.contains('_') && widget.callId.split('_').length >= 3 && !widget.callId.startsWith('chat_'));
    
    // Arama sonlandırma callback'ini ayarla
    _callService.onCallEnded = () {
      print('📞 Arama sonlandırma callback\'i çağrıldı');
      if (mounted) {
        Navigator.of(context).pop();
      }
    };
    
    if (isMatchingCall) {
      // Eşleştirme araması - direkt bağlantı kur
      print('🎯 Eşleştirme araması başlatılıyor...');
      await _startMatchingCall();
         } else {
       // Normal arama - eski sistemi kullan
       final receiverId = _extractReceiverId(widget.callId);
       
       // Karşı tarafın bilgilerini yükle
       await _loadOtherUserData(receiverId);
       
       if (widget.isCaller) {
         await _callService.startCall(receiverId);
         _status = 'Arama başlatıldı, bekleniyor...';
       } else {
         await _callService.answerCall(widget.callId);
         _status = 'Arama kabul edildi, bağlanıyor...';
       }
       _callService.listenForSignaling();
     }
    
    setState(() {
      _localRenderer.srcObject = _callService.localStream;
    });
    // Sayaç sadece bağlantı kurulduğunda başlayacak, burada başlatma
  }

  // Eşleştirme araması için özel fonksiyon
  Future<void> _startMatchingCall() async {
    try {
      // Direkt WebRTC bağlantısı kur (calls koleksiyonu kullanmadan)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // CallId'den diğer kullanıcının ID'sini çıkar
      final parts = widget.callId.split('_');
      final otherUserId = parts[0] == user.uid ? parts[1] : parts[0];
      
      print('🎯 Eşleştirme araması: ${user.uid} <-> $otherUserId (isCaller: ${widget.isCaller})');
      
      // Karşı tarafın bilgilerini çek
      await _loadOtherUserData(otherUserId);
      
      // WebRTC bağlantısını başlat (yeni eşleştirme fonksiyonunu kullan)
      await _callService.startMatchingCall(
        otherUserId, 
        isCaller: widget.isCaller, 
        callId: widget.callId
      );
      _status = 'Eşleştirme araması başlatıldı, bağlanıyor...';
      
      // Signaling dinle (yeni eşleştirme signaling fonksiyonunu kullan)
      _callService.listenForMatchingSignaling(widget.callId);
      
         } catch (e) {
       print('❌ Eşleştirme araması hatası: $e');
       setState(() {
         _status = 'Bağlantı hatası: $e';
       });
       
       // Hata durumunda kuyruktan çıkar
       try {
         await MatchingService.leaveQueue();
         print('🚪 Hata durumunda kuyruktan çıkarıldı');
       } catch (queueError) {
         print('⚠️ Kuyruktan çıkarma hatası: $queueError');
       }
       
       // 3 saniye sonra ana sayfaya dön
       Future.delayed(Duration(seconds: 3), () {
         if (mounted) {
           Navigator.of(context).pop();
         }
       });
     }
  }

  // Karşı tarafın kullanıcı bilgilerini çek
  Future<void> _loadOtherUserData(String otherUserId) async {
    try {
      setState(() {
        _isLoadingUserData = true;
      });
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _otherUserData = userData;
          _otherUserName = userData['name'] ?? 'Bilinmeyen Kullanıcı';
          _otherUserProfileImage = userData['profileImageUrl'];
        });
        print('👤 Karşı taraf bilgileri yüklendi: $_otherUserName');
      } else {
        print('❌ Karşı taraf kullanıcı bulunamadı: $otherUserId');
      }
    } catch (e) {
      print('❌ Kullanıcı bilgileri yükleme hatası: $e');
    } finally {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callSeconds = 0;
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _callSeconds++;
      });
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  String _extractReceiverId(String callId) {
    // callId: chat_callerId_receiverId_timestamp veya callerId_receiverId_timestamp
    final parts = callId.split('_');
    if (callId.startsWith('chat_') && parts.length >= 4) {
      return parts[2]; // chat_callerId_receiverId_timestamp
    } else if (parts.length >= 3) {
      return parts[1]; // callerId_receiverId_timestamp
    }
    return '';
  }

     void _toggleMic() async {
     // Chat araması mı kontrol et
     final isChatCall = widget.callId.startsWith('chat_');
     
     if (isChatCall) {
       // Normal arama - eski sistemi kullan
       await _callService.setMicEnabled(!_micEnabled);
       setState(() {
         _micEnabled = !_micEnabled;
       });
       print('🎤 Normal arama - mikrofon ${_micEnabled ? "açık" : "kapalı"}');
     } else {
       // Eşleştirme araması - sadece mikrofonu aç/kapat
       await _callService.setMicEnabled(!_micEnabled, isCaller: widget.isCaller);
       setState(() {
         _micEnabled = !_micEnabled;
       });
       print('🎤 Eşleştirme araması - mikrofon ${_micEnabled ? "açık" : "kapalı"}');
     }
   }

  void _toggleSpeaker() async {
    await Helper.setSpeakerphoneOn(!_speakerOn);
    setState(() {
      _speakerOn = !_speakerOn;
    });
  }

     void _listenForRemoteMute() {
     if (widget.callId.isEmpty) return;
     
     // Chat araması mı kontrol et
     final isChatCall = widget.callId.startsWith('chat_');
     
     // Sadece chat aramaları için remote mute dinle
     if (isChatCall) {
       FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) {
         final data = doc.data();
         if (data != null) {
           bool remoteMuted = widget.isCaller ? (data['mutedByCallee'] ?? false) : (data['mutedByCaller'] ?? false);
           setState(() {
             _remoteRenderer.muted = remoteMuted;
           });
         }
       });
     } else {
       print('🎯 Eşleştirme araması - remote mute dinleme devre dışı');
     }
   }

  void _endCall() async {
    setState(() {
      _status = 'Çağrı sonlandırıldı';
    });
    _stopCallTimer();
    
    // WebRTC bağlantısını kapat
    await _callService.endCall();
    
    Navigator.of(context).pop();
  }

     @override
   Widget build(BuildContext context) {
     // Chat araması mı kontrol et
     final isChatCall = widget.callId.startsWith('chat_');
    
    return Scaffold(
             appBar: AppBar(
         title: Text(widget.callId.startsWith('chat_') ? 'Sesli Arama' : 'Eşleştirme Araması'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.call_end, color: Colors.red),
            onPressed: _endCall,
            tooltip: 'Çağrıyı Bitir',
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          
                     // Karşı tarafın bilgileri (hem eşleştirme hem normal arama için)
           if (_otherUserName != 'Bilinmeyen Kullanıcı') ...[
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  // Profil resmi
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: _otherUserProfileImage != null 
                      ? NetworkImage(_otherUserProfileImage!) 
                      : null,
                    child: _otherUserProfileImage == null 
                      ? Icon(Icons.person, size: 30, color: Colors.grey)
                      : null,
                  ),
                  SizedBox(width: 16),
                  // Kullanıcı bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otherUserName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        if (_otherUserData != null) ...[
                          SizedBox(height: 4),
                          Text(
                            '${_otherUserData!['city'] ?? 'Bilinmeyen Şehir'} • ${_otherUserData!['gender'] ?? 'Bilinmeyen'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_otherUserData!['bio'] != null && _otherUserData!['bio'].isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(
                              _otherUserData!['bio'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  // Yükleniyor göstergesi
                  if (_isLoadingUserData)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
          
          Text(_status, style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          // Arama süresi göstergesi
          if (_callSeconds > 0)
            Text(_formatDuration(_callSeconds), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('Sen'),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                  ),
                ],
              ),
              Column(
                children: [
                                     Text(isChatCall ? _otherUserName : 'Karşı Taraf'),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
                onPressed: _toggleMic,
                tooltip: _micEnabled ? 'Mikrofonu Kapat' : 'Mikrofonu Aç',
                color: _micEnabled ? Colors.green : Colors.grey,
                iconSize: 36,
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: Icon(_speakerOn ? Icons.volume_up : Icons.hearing),
                onPressed: _toggleSpeaker,
                tooltip: _speakerOn ? 'Hoparlör Kapat' : 'Hoparlöre Ver',
                color: _speakerOn ? Colors.blue : Colors.grey,
                iconSize: 36,
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: Icon(Icons.call_end),
                onPressed: _endCall,
                color: Colors.red,
                iconSize: 36,
                tooltip: 'Çağrıyı Bitir',
              ),
            ],
          ),
        ],
      ),
    );
  }
}