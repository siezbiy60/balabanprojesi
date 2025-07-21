import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'chat_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BalabanProje',
      theme: ThemeData(
        primaryColor: Color(0xFFF5C6CB), // Soft Pembe
        scaffoldBackgroundColor: Color(0xFFF9F1F5), // Hafif Gri-Pembe
        colorScheme: ColorScheme.light(
          primary: Color(0xFFF5C6CB),
          secondary: Color(0xFFD8BFD8), // Pastel Mor
          onPrimary: Color(0xFF4A4A4A), // Yazı rengi
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFC71585), // Koyu Pembe
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF4A4A4A)),
          headlineSmall: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => AuthWrapper(),
        '/login': (context) => LoginPage(),
        '/profile': (context) => ProfilePage(),
        '/chat': (context) => ChatPage(
          receiverId: '', // Dinamik olarak sağlanacak
          receiverUsername: '',
        ),
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