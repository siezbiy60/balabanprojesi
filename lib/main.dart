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
import 'package:provider/provider.dart';
import 'webrtc_call_page.dart';
import 'matching_service.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balaban Proje',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChangeNotifierProvider.value(
        value: incomingCallOverlayController,
        child: MainApp(),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
    _saveFcmToken();
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
    return MaterialApp(
      title: 'BalabanProje',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1976D2), // Mavi
        scaffoldBackgroundColor: const Color(0xFFF6F8FC), // Soft açık gri
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF222222),
          elevation: 0.5,
          iconTheme: IconThemeData(color: Color(0xFF1976D2)),
          titleTextStyle: TextStyle(
            color: Color(0xFF222222), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.2,
          ),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1976D2), // Mavi
          secondary: Color(0xFF64B5F6), // Açık mavi
          onPrimary: Colors.white,
          surface: Color(0xFFF6F8FC),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF222222), fontSize: 16),
          headlineSmall: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 22),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE3E6ED),
          thickness: 1,
        ),
        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          tileColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF232B3E),
        scaffoldBackgroundColor: const Color(0xFF181A20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF232B3E),
          foregroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: IconThemeData(color: Color(0xFF90CAF9)),
          titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.2,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF90CAF9), // Açık mavi
          secondary: Color(0xFF1976D2), // Mavi
          onPrimary: Colors.white,
          surface: Color(0xFF232B3E),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
          headlineSmall: TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.bold, fontSize: 22),
        ),
        cardTheme: CardThemeData(
          color: Color(0xFF232B3E),
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF232B3E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF90CAF9)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2C3142),
          thickness: 1,
        ),
        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          tileColor: Color(0xFF232B3E),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      themeMode: ThemeMode.system,
      home: Stack(
        children: [
          AuthWrapper(),
          Consumer<IncomingCallOverlayController>(
            builder: (context, overlay, child) {
              if (!overlay.visible) return SizedBox.shrink();
              return Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${overlay.callerName} sizi arıyor!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                                                         ElevatedButton(
                               onPressed: () async {
                                 overlay.hide();
                                 
                                 try {
                                   // Voice call dokümantından caller ID'yi al
                                   final callDoc = await FirebaseFirestore.instance
                                       .collection('calls')
                                       .doc(overlay.peerId!)
                                       .get();
                                   
                                   if (callDoc.exists) {
                                     Navigator.of(context).push(
                                       MaterialPageRoute(builder: (context) => WebRTCCallPage(callId: overlay.peerId!, isCaller: false)),
                                     );
                                   }
                                 } catch (e) {
                                   print('Call bilgisi alınamadı: $e');
                                 }
                               },
                              child: Text('Kabul Et'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                overlay.hide();
                                // Reddetme işlemi: İstersen Firestore'a "rejected" yazabilirsin
                              },
                              child: Text('Reddet'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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