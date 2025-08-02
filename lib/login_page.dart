import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'profile_setup_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final rememberMe = prefs.getBool('remember_me') ?? false;
      
      if (rememberMe && savedEmail != null && savedPassword != null) {
        if (mounted) {
          setState(() {
            _emailController.text = savedEmail;
            _passwordController.text = savedPassword;
            _rememberMe = true;
          });
        }
      }
    } catch (e) {
      print('Kayıtlı bilgiler yüklenemedi: $e');
      // Web için localStorage kullanmayı dene
      try {
        // Web için localStorage kontrolü
        if (kIsWeb) {
          // Web'de SharedPreferences yerine localStorage kullan
          print('Web platformu tespit edildi, localStorage kullanılıyor');
        }
      } catch (webError) {
        print('Web localStorage hatası: $webError');
      }
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      print('Bilgiler kaydedilemedi: $e');
    }
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
        print('✅ FCM Token kaydedildi: ${token.substring(0, 20)}...');
      } else {
        print('❌ FCM Token alınamadı');
      }
    } catch (e) {
      print('❌ FCM Token kaydetme hatası: $e');
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Giriş yapılıyor: ${_emailController.text.trim()}');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print('Giriş başarılı, kullanıcı: ${userCredential.user?.uid}');

      if (userCredential.user?.emailVerified ?? false) {
        print('E-posta doğrulanmış, profil kontrol ediliyor...');
        
        // Bilgileri kaydet
        await _saveCredentials();
        
        // FCM Token'ı kaydet
        await _saveFcmToken(userCredential.user!.uid);
        
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (userDoc.exists) {
          print('Profil mevcut, HomePage’e yönlendiriliyor...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } else {
          print('Profil yok, ProfileSetupPage’e yönlendiriliyor...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ProfileSetupPage()),
          );
        }
      } else {
        print('E-posta doğrulanmamış, doğrulama e-postası gönderiliyor...');
        await userCredential.user?.sendEmailVerification();
        if (mounted) {
          setState(() {
            _errorMessage = 'Lütfen e-postanızı doğrulayın. Doğrulama linki gönderildi.';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuth hatası: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e.code);
        });
      }
    } catch (e) {
      print('Genel hata: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Bir hata oluştu: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Kayıt olunuyor: ${_emailController.text.trim()}');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print('Kayıt başarılı, kullanıcı: ${userCredential.user?.uid}');
      await userCredential.user?.sendEmailVerification();
      if (mounted) {
        setState(() {
          _errorMessage = 'Kayıt başarılı! Lütfen e-postanıza gelen doğrulama linkine tıklayın.';
        });
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuth hatası: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e.code);
        });
      }
    } catch (e) {
      print('Genel hata: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Bir hata oluştu: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Yanlış şifre.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      default:
        return 'Bir hata oluştu: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(title: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'E-posta gerekli.' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                ),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Şifre gerekli.' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text('Beni Hatırla'),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              _isLoading
                  ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))
                  : ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _isLogin ? _signIn() : _signUp();
                  }
                },
                child: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  });
                },
                child: Text(_isLogin
                    ? 'Hesabın yok mu? Kayıt ol'
                    : 'Zaten hesabın var mı? Giriş yap'),
              ),
              if (!_isLogin && _errorMessage != null)
                TextButton(
                  onPressed: () async {
                    try {
                      print('Doğrulama e-postası tekrar gönderiliyor...');
                      await _auth.currentUser?.sendEmailVerification();
                            if (mounted) {
        setState(() {
          _errorMessage = 'Doğrulama e-postası tekrar gönderildi.';
        });
      }
                    } catch (e) {
                      print('Doğrulama e-postası hatası: $e');
                            if (mounted) {
        setState(() {
          _errorMessage = 'Hata: $e';
        });
      }
                    }
                  },
                  child: const Text('Doğrulama E-postasını Tekrar Gönder'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}