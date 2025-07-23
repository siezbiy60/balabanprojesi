import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'chat_page.dart';
import 'profile_edit_page.dart';
import 'firebase_options.dart';
import 'friend_requests_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) {
        // ignore if user doc doesn't exist yet
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BalabanProje',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF1976D2), // Mavi
        scaffoldBackgroundColor: Color(0xFFF5F6FA), // Hafif açık gri
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF222222),
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF1976D2)),
          titleTextStyle: TextStyle(
            color: Color(0xFF222222), fontSize: 20, fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF1976D2), // Mavi
          secondary: Color(0xFF64B5F6), // Açık mavi
          onPrimary: Colors.white,
          background: Color(0xFFF5F6FA),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF222222)),
          headlineSmall: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        iconTheme: IconThemeData(color: Color(0xFF1976D2)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF121212),
        scaffoldBackgroundColor: Color(0xFF181A20),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF23272F),
          foregroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF90CAF9)),
          titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF90CAF9), // Açık mavi
          secondary: Color(0xFF1976D2), // Mavi
          onPrimary: Colors.white,
          background: Color(0xFF181A20),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: Color(0xFF23272F),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23272F),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        iconTheme: IconThemeData(color: Color(0xFF90CAF9)),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => AuthWrapper(),
        '/login': (context) => LoginPage(),
        '/profile': (context) => ProfilePage(),
        '/chat': (context) => ChatPage(
          receiverId: '', // Dinamik olarak sağlanacak
          receiverUsername: '',
        ),
        '/profile_edit': (context) => ProfileEditPage(),
        '/friend_requests': (context) => FriendRequestsPage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (user.emailVerified) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(body: Center(child: CircularProgressIndicator()));
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