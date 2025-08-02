import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCCallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _callId;
  Function(MediaStream stream)? onRemoteStream;
  Function()? onCallEnded; // Arama sonlandığında çağrılacak callback
  RTCRtpSender? _audioSender;
  bool _isMicEnabled = true;

  // PeerConnection ve mikrofonu başlat
  Future<String> startCall(String receiverId) async {
    // Mikrofon izni iste
    if (!await Permission.microphone.request().isGranted) {
      throw Exception('Mikrofon izni verilmedi!');
    }
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış');
    _callId = 'chat_${user.uid}_${receiverId}_${DateTime.now().millisecondsSinceEpoch}';
    
    // PeerConnection oluştur - Gelişmiş ayarlar
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    // Mikrofonu aç - Gelişmiş audio constraints
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'sampleRate': 48000,
        'channelCount': 1,
      },
      'video': false,
    });
    
    print('🎤 Audio tracks (startCall): ${_localStream!.getAudioTracks()}');
    for (var track in _localStream!.getAudioTracks()) {
      _audioSender = await _peerConnection!.addTrack(track, _localStream!);
    }
    print('🎤 Senders (startCall): ${_peerConnection!.getSenders()}');

    // Remote stream geldiğinde callback
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty && onRemoteStream != null) {
        onRemoteStream!(event.streams[0]);
      }
    };

    // ICE Candidate Firestore'a yaz
    _peerConnection!.onIceCandidate = (candidate) {
      _firestore.collection('calls').doc(_callId).collection('candidates').add(candidate.toMap());
    };

    // SDP Offer oluştur
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Firestore'a arama dokümanı yaz
    await _firestore.collection('calls').doc(_callId).set({
      'callerId': user.uid,
      'receiverId': receiverId,
      'status': 'calling',
      'offer': offer.toMap(),
    });
    return _callId!;
  }

  // Gelen aramayı cevapla
  Future<void> answerCall(String callId) async {
    // Mikrofon izni iste
    if (!await Permission.microphone.request().isGranted) {
      throw Exception('Mikrofon izni verilmedi!');
    }
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış');
    _callId = callId;

    // PeerConnection oluştur - Gelişmiş ayarlar
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    // Mikrofonu aç - Gelişmiş audio constraints
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'sampleRate': 48000,
        'channelCount': 1,
      },
      'video': false,
    });
    
    print('🎤 Audio tracks (answerCall): ${_localStream!.getAudioTracks()}');
    for (var track in _localStream!.getAudioTracks()) {
      _audioSender = await _peerConnection!.addTrack(track, _localStream!);
    }
    print('🎤 Senders (answerCall): ${_peerConnection!.getSenders()}');

    // Remote stream geldiğinde callback
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty && onRemoteStream != null) {
        onRemoteStream!(event.streams[0]);
      }
    };

    // ICE Candidate Firestore'a yaz
    _peerConnection!.onIceCandidate = (candidate) {
      _firestore.collection('calls').doc(_callId).collection('candidates').add(candidate.toMap());
    };

    // Firestore'dan offer'ı al
    DocumentSnapshot callDoc = await _firestore.collection('calls').doc(_callId).get();
    var offer = callDoc['offer'];
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));

    // Answer oluştur
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Firestore'a answer'ı yaz
    await _firestore.collection('calls').doc(_callId).update({
      'answer': answer.toMap(),
      'status': 'in_call',
    });
  }

  // Karşı tarafın offer/answer ve ICE candidate'larını dinle ve uygula
  void listenForSignaling() {
    if (_callId == null) return;
    
    // Chat araması mı kontrol et
    final isChatCall = _callId!.startsWith('chat_');
    
    // Answer geldiğinde peer'a uygula ve arama sonlandırma durumunu dinle
    _firestore.collection('calls').doc(_callId).snapshots().listen((doc) async {
      if (!doc.exists) {
        print('📞 Arama dokümanı silindi, arama sonlandırılıyor');
        if (_peerConnection != null && _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          await endCall();
          if (onCallEnded != null) {
            onCallEnded!();
          }
        }
        return;
      }
      
      final data = doc.data();
      if (data != null) {
        // Arama sonlandırma durumunu kontrol et
        if (data['status'] == 'ended') {
          print('📞 Diğer kullanıcı aramayı sonlandırdı (status: ended)');
          if (_peerConnection != null && _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
            await endCall();
            if (onCallEnded != null) {
              onCallEnded!();
            }
          }
          return;
        }
        
        // Answer geldiğinde peer'a uygula
        if (data['answer'] != null && _peerConnection?.signalingState != RTCSignalingState.RTCSignalingStateStable) {
          var answer = data['answer'];
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
        }
      }
    });
    
    // ICE candidate'ları uygula
    _firestore.collection('calls').doc(_callId).collection('candidates').snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        var data = doc.doc.data();
        if (data != null) {
          _peerConnection?.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
        }
      }
    });
  }

  // Çağrıyı bitir
  Future<void> endCall() async {
    print('📞 endCall() çağrıldı, _callId: $_callId');
    
    await _peerConnection?.close();
    await _localStream?.dispose();
    
    if (_callId == null) return;
    
    // Chat araması mı kontrol et
    final isChatCall = _callId!.startsWith('chat_');
    
    if (isChatCall) {
      // Chat araması - calls koleksiyonunu temizle
      try {
        await _firestore.collection('calls').doc(_callId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
        print('📞 Chat araması sonlandırma bildirimi gönderildi: $_callId');
        
        // Kısa bir süre sonra dokümanı sil
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            await _firestore.collection('calls').doc(_callId).delete();
            print('📞 Chat arama dokümanı silindi: $_callId');
          } catch (e) {
            print('❌ Chat arama dokümanı silme hatası: $e');
          }
        });
      } catch (e) {
        print('❌ Chat arama sonlandırma hatası: $e');
        // Doküman yoksa silmeyi dene
        try {
          await _firestore.collection('calls').doc(_callId).delete();
          print('📞 Chat arama dokümanı silindi: $_callId');
        } catch (deleteError) {
          print('❌ Chat arama dokümanı silme hatası: $deleteError');
        }
      }
    } else {
      // Eşleştirme araması - diğer kullanıcıya bildir ve kuyrukları temizle
      final matchingCallId = 'matching_$_callId';
      try {
        // Önce mevcut kullanıcıyı kuyruktan çıkar
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('matching_queue').doc(user.uid).delete();
          print('📞 Mevcut kullanıcı kuyruktan çıkarıldı: ${user.uid}');
        }
        
        // Diğer kullanıcıyı da kuyruktan çıkar
        final parts = _callId!.split('_');
        final otherUserId = parts[0] == user?.uid ? parts[1] : parts[0];
        try {
          await _firestore.collection('matching_queue').doc(otherUserId).delete();
          print('📞 Diğer kullanıcı kuyruktan çıkarıldı: $otherUserId');
        } catch (e) {
          print('⚠️ Diğer kullanıcı kuyruktan çıkarılırken hata: $e');
        }
        
        // Arama durumunu güncelle
        await _firestore.collection('matching_calls').doc(matchingCallId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
        print('📞 Eşleştirme arama sonlandırma bildirimi gönderildi: $matchingCallId');
      } catch (e) {
        print('❌ Eşleştirme arama sonlandırma hatası: $e');
        // Doküman yoksa silmeyi dene
        try {
          await _firestore.collection('matching_calls').doc(matchingCallId).delete();
          print('📞 Eşleştirme arama dokümanı silindi: $matchingCallId');
        } catch (deleteError) {
          print('❌ Eşleştirme arama dokümanı silme hatası: $deleteError');
        }
      }
    }
    
    _callId = null;
    _peerConnection = null;
    _localStream = null;
    _audioSender = null;
  }

  // Mikrofonu aç/kapat
  Future<void> setMicEnabled(bool enabled, {bool? isCaller}) async {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
      _isMicEnabled = enabled;
      
      // Eşleştirme araması için Firestore'a yazma (calls koleksiyonu kullanmıyoruz)
      if (isCaller != null) {
        // Bu eşleştirme araması, Firestore'a yazmaya gerek yok
        print('🎤 Eşleştirme araması - mikrofon ${enabled ? "açık" : "kapalı"}');
      } else {
        // Normal arama için Firestore'a yaz
        try {
          if (_callId != null) {
            await _firestore.collection('calls').doc(_callId).update({
              'mutedByCaller': !enabled,
            });
          }
        } catch (e) {
          print('❌ Firestore mute durumu güncellenirken hata: $e');
        }
      }
      
      print('🎤 Mikrofon durumu güncellendi: ${enabled ? "Açık" : "Kapalı"}');
    } else {
      print('❌ Local stream bulunamadı!');
    }
  }

  // Mikrofon durumunu kontrol et
  bool get isMicEnabled => _isMicEnabled;

  MediaStream? get localStream => _localStream;

  // Eşleştirme araması için özel fonksiyon (calls koleksiyonu kullanmaz)
  Future<void> startMatchingCall(String otherUserId, {required bool isCaller, required String callId}) async {
    // Mikrofon izni iste
    if (!await Permission.microphone.request().isGranted) {
      throw Exception('Mikrofon izni verilmedi!');
    }
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapılmamış');
    
    // CallId'yi set et
    _callId = callId;
    
    print('🎯 Eşleştirme araması başlatılıyor: ${user.uid} <-> $otherUserId (isCaller: $isCaller, callId: $callId)');
    
    // PeerConnection oluştur - Gelişmiş ayarlar
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    // Mikrofonu aç - Gelişmiş audio constraints
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'sampleRate': 48000,
        'channelCount': 1,
      },
      'video': false,
    });
    
    print('🎤 Audio tracks (startMatchingCall): ${_localStream!.getAudioTracks()}');
    for (var track in _localStream!.getAudioTracks()) {
      _audioSender = await _peerConnection!.addTrack(track, _localStream!);
    }
    print('🎤 Senders (startMatchingCall): ${_peerConnection!.getSenders()}');

    // Remote stream geldiğinde callback
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty && onRemoteStream != null) {
        onRemoteStream!(event.streams[0]);
      }
    };

    // ICE Candidate Firestore'a yaz
    _peerConnection!.onIceCandidate = (candidate) {
      final matchingCallId = 'matching_$callId';
      _firestore.collection('matching_calls').doc(matchingCallId).collection('candidates').add(candidate.toMap());
    };

         if (isCaller) {
       // Caller: Offer oluştur
       print('📄 Caller: Offer oluşturuluyor...');
       RTCSessionDescription offer = await _peerConnection!.createOffer();
       await _peerConnection!.setLocalDescription(offer);

       // Firestore'a eşleştirme arama dokümanı yaz
       final matchingCallId = 'matching_$callId';
       try {
         await _firestore.collection('matching_calls').doc(matchingCallId).set({
           'callerId': user.uid,
           'receiverId': otherUserId,
           'status': 'calling',
           'offer': offer.toMap(),
           'createdAt': FieldValue.serverTimestamp(),
         });
         
         print('✅ Caller: Eşleştirme araması başlatıldı: $matchingCallId');
       } catch (e) {
         print('❌ Caller: Firestore yazma hatası: $e');
         throw Exception('Arama başlatılamadı: $e');
       }
         } else {
       // Answerer: Offer'ı bekle ve answer oluştur
       final matchingCallId = 'matching_$callId';
       
       print('🎯 Answerer: Offer bekleniyor... $matchingCallId');
       
       // Offer'ı bekle - daha uzun süre ve daha sık kontrol et
       DocumentSnapshot? callDoc;
       int attempts = 0;
       const maxAttempts = 60; // 60 saniye bekle
       
                while (attempts < maxAttempts) {
           try {
             callDoc = await _firestore.collection('matching_calls').doc(matchingCallId).get();
             final data = callDoc.data() as Map<String, dynamic>?;
             if (callDoc.exists && data != null && data['offer'] != null) {
               print('✅ Offer bulundu! Deneme: ${attempts + 1}');
               break;
             }
           } catch (e) {
             print('⚠️ Offer kontrol hatası: $e');
           }
         
         await Future.delayed(Duration(milliseconds: 500)); // 500ms bekle
         attempts++;
         
         if (attempts % 10 == 0) { // Her 5 saniyede bir log
           print('⏳ Offer bekleniyor... ${attempts * 0.5} saniye geçti');
         }
       }
       
                if (callDoc != null && callDoc.exists) {
           final data = callDoc.data() as Map<String, dynamic>?;
           if (data != null && data['offer'] != null) {
             var offer = data['offer'];
             print('📄 Offer alındı, remote description set ediliyor...');
         
         await _peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));

         // Answer oluştur
         print('📄 Answer oluşturuluyor...');
         RTCSessionDescription answer = await _peerConnection!.createAnswer();
         await _peerConnection!.setLocalDescription(answer);

         // Firestore'a answer'ı yaz
         await _firestore.collection('matching_calls').doc(matchingCallId).update({
           'answer': answer.toMap(),
           'status': 'in_call',
           'answeredAt': FieldValue.serverTimestamp(),
         });
         
         print('✅ Answerer: Eşleştirme araması cevaplandı: $matchingCallId');
                } else {
           print('❌ Offer bulunamadı! Deneme sayısı: $attempts');
           throw Exception('Offer bulunamadı! 30 saniye beklendi.');
         }
       }
     }
  }

  // Eşleştirme araması için signaling dinle
  void listenForMatchingSignaling(String callId) {
    final matchingCallId = 'matching_$callId';
    print('🎧 Eşleştirme signaling dinleniyor: $matchingCallId');
    
    // Answer geldiğinde peer'a uygula (sadece caller için)
    _firestore.collection('matching_calls').doc(matchingCallId).snapshots().listen((doc) async {
      print('📄 Eşleştirme doküman güncellemesi: ${doc.exists}');
      
      if (!doc.exists) {
        print('📞 Eşleştirme arama dokümanı silindi, arama sonlandırılıyor');
        if (_peerConnection != null && _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // Mevcut kullanıcıyı kuyruktan çıkar
          final user = _auth.currentUser;
          if (user != null) {
            try {
              await _firestore.collection('matching_queue').doc(user.uid).delete();
              print('📞 Mevcut kullanıcı kuyruktan çıkarıldı (doküman silindi): ${user.uid}');
            } catch (e) {
              print('⚠️ Kullanıcı kuyruktan çıkarılırken hata: $e');
            }
          }
          
          await endCall();
          if (onCallEnded != null) {
            onCallEnded!();
          }
        }
        return;
      }
      
      final data = doc.data();
      if (data != null && data['answer'] != null && _peerConnection?.signalingState != RTCSignalingState.RTCSignalingStateStable) {
        var answer = data['answer'];
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
        print('✅ Answer alındı ve uygulandı');
      }
      
      // Arama durumu kontrol et
      if (data != null && data['status'] == 'ended') {
        print('📞 Diğer kullanıcı aramayı sonlandırdı (status: ended)');
        if (_peerConnection != null && _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // Mevcut kullanıcıyı kuyruktan çıkar
          final user = _auth.currentUser;
          if (user != null) {
            try {
              await _firestore.collection('matching_queue').doc(user.uid).delete();
              print('📞 Mevcut kullanıcı kuyruktan çıkarıldı (status ended): ${user.uid}');
            } catch (e) {
              print('⚠️ Kullanıcı kuyruktan çıkarılırken hata: $e');
            }
          }
          
          await endCall();
          if (onCallEnded != null) {
            onCallEnded!();
          }
        }
      }
    });
    
    // ICE candidate'ları uygula
    _firestore.collection('matching_calls').doc(matchingCallId).collection('candidates').snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        var data = doc.doc.data();
        if (data != null) {
          _peerConnection?.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
        }
      }
    });
  }
}