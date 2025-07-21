import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_setup_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String? _errorMessage;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        setState(() {
          _errorMessage = 'Lütfen e-postanızı doğrulayın. Doğrulama linki gönderildi.';
        });
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuth hatası: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      print('Genel hata: $e');
      setState(() {
        _errorMessage = 'Bir hata oluştu: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      setState(() {
        _errorMessage = 'Kayıt başarılı! Lütfen e-postanıza gelen doğrulama linkine tıklayın.';
      });
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuth hatası: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      print('Genel hata: $e');
      setState(() {
        _errorMessage = 'Bir hata oluştu: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                decoration: InputDecoration(labelText: 'E-posta'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'E-posta gerekli.' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Şifre'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Şifre gerekli.' : null,
              ),
              SizedBox(height: 16),
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              SizedBox(height: 16),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
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
                      setState(() {
                        _errorMessage = 'Doğrulama e-postası tekrar gönderildi.';
                      });
                    } catch (e) {
                      print('Doğrulama e-postası hatası: $e');
                      setState(() {
                        _errorMessage = 'Hata: $e';
                      });
                    }
                  },
                  child: Text('Doğrulama E-postasını Tekrar Gönder'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}