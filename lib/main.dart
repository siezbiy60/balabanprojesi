import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';
import 'home_page.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'webrtc_call_page.dart';
import 'matching_service.dart';
import 'theme_service.dart';
import 'online_status_service.dart';

class IncomingCallOverlayController extends ChangeNotifier {
  String? callerName;
  String? peerId;
  bool visible = false;
  void show(String caller, String peer) {
    callerName = caller;
    peerId = peer;
    visible = true;
    notifyListeners();
  }
  void hide() {
    visible = false;
    notifyListeners();
  }
}
final incomingCallOverlayController = IncomingCallOverlayController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i sadece bir kez initialize et
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Eğer zaten initialize edilmişse, hata verme
    if (e.toString().contains('duplicate-app')) {
      print('Firebase zaten initialize edilmiş');
    } else {
      rethrow;
    }
  }
  await initializeDateFormatting('tr_TR', null);

  // MatchingService'i başlat - eski kayıtları temizle
  await MatchingService.initialize();

  // Bildirimlerin foreground'da da gösterilmesi için ayar
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Background/terminated handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Text(
          details.exceptionAsString(),
          style: const TextStyle(color: Colors.red, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  };
  runApp(MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda gelen arama bildirimi için log
  print('Arka planda gelen bildirim: ${message.data}');
  
  // Firebase'i initialize et
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Mesaj bildirimi kontrol et
  if (message.data.containsKey('type') && message.data['type'] == 'message') {
    print('📱 Arka plan mesaj bildirimi: ${message.data}');
    
    // Local notification göster
    // Bu kısım için flutter_local_notifications paketi gerekebilir
    // Şimdilik sadece log yazdırıyoruz
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: incomingCallOverlayController),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: ThemeService.themeNotifier,
        builder: (context, isDarkMode, child) {
          return MaterialApp(
            title: 'Balaban Proje',
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: MainApp(),
          );
        },
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Timer? _activityTimer;
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
    _saveFcmToken();
    OnlineStatusService.setOnline();
    
    // Her 2 dakikada bir son aktif zamanını güncelle
    _activityTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      OnlineStatusService.updateLastActive();
    });
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    OnlineStatusService.setOffline();
    super.dispose();
  }

  Future<void> _saveFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Bildirim izinlerini kontrol et
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        print('📱 Bildirim izinleri: ${settings.authorizationStatus}');
        
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          print('❌ Bildirim izni reddedildi, izin isteniyor...');
          final permission = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
          print('📱 İzin sonucu: ${permission.authorizationStatus}');
        }
        
        // Android için notification channel ayarları
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'fcmToken': token,
          });
          print('✅ FCM Token kaydedildi: ${token.substring(0, 20)}...');
        } else {
          print('❌ FCM Token alınamadı');
        }
      } else {
        print('❌ Kullanıcı giriş yapmamış');
      }
    } catch (e) {
      print('❌ FCM Token kaydetme hatası: $e');
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // Uygulama kapalıyken açılan bildirimleri kontrol et
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('Uygulama kapalıyken açılan bildirim: ${initialMessage.data}');
      _handleCallNotification(initialMessage.data);
    }

    // Uygulama açıkken gelen bildirimler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📱 Foreground bildirim alındı');
      print('📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
      print('📱 Data: ${message.data}');
      
      final data = message.data;
      final notification = message.notification;
      
      // Mesaj bildirimi kontrol et
      if (data.containsKey('type') && data['type'] == 'message') {
        print('📱 Mesaj bildirimi alındı');
        print('📱 Data: $data');
        print('📱 Notification: ${notification?.title} - ${notification?.body}');
        
        // Foreground'da mesaj bildirimi için snackbar göster
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${notification?.title ?? 'Yeni Mesaj'}: ${notification?.body ?? 'Mesaj geldi'}'),
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Görüntüle',
                onPressed: () {
                  // Mesajlar sayfasına git
                  Navigator.pushNamed(context, '/messages');
                },
              ),
            ),
          );
        } catch (e) {
          print('❌ SnackBar gösterilemedi: $e');
        }
      }
      
      // Test bildirimi kontrol et
      if (data.containsKey('type') && data['type'] == 'test') {
        print('🧪 Test bildirimi alındı');
        // ScaffoldMessenger hatası için try-catch kullan
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${notification?.title ?? 'Test'}: ${notification?.body ?? 'Test mesajı'}'),
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          print('❌ SnackBar gösterilemedi: $e');
        }
      }
      
      // Arama bildirimi kontrol et
      if (data.containsKey('callId')) {
        // Arayanın adını Firestore'dan çek
        final callId = data['callId'];
        final callerId = data['callerId'];
        final callerDoc = await FirebaseFirestore.instance.collection('users').doc(callerId).get();
        final callerName = callerDoc.data()?['username'] ?? 'Bilinmeyen';
        incomingCallOverlayController.show(callerName, callId);
      }
    });

    // Uygulama arka plandayken bildirime tıklama
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Background bildirim tıklandı: ${message.data}');
      _handleCallNotification(message.data);
    });

    // Arka planda gelen data-only mesajlar
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _handleCallNotification(Map<String, dynamic> data) async {
    if (data.containsKey('callId')) {
      final callId = data['callId'];
      print('WebRTCCallPage açılıyor, callId: $callId');
      
      try {
        // Chat araması için callId'yi doğrudan kullan
        if (callId.startsWith('chat_')) {
          // Kısa bir gecikme ekleyerek context'in hazır olmasını bekle
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => WebRTCCallPage(callId: callId, isCaller: false)),
              );
            }
          });
        } else {
          // Eşleştirme araması için eski sistemi kullan
          final callDoc = await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .get();
          
          if (callDoc.exists) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => WebRTCCallPage(callId: callId, isCaller: false)),
                );
              }
            });
          }
        }
      } catch (e) {
        print('Call bilgisi alınamadı: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // İkinci MaterialApp'ı kaldır, sadece ana widget'ı döndür
    // Örneğin:
    // return HomePage();
    // veya ana sayfan neyse onu döndür
    return HomePage();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (user.emailVerified) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasData && snapshot.data!.exists) {
                  return HomePage();
                }
                return ProfileSetupPage();
              },
            );
          } else {
            return LoginPage();
          }
        }
        return LoginPage();
      },
    );
  }
}