import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  @override
  _ProfileSetupPageState createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _cityController = TextEditingController();
  String? _gender;
  File? _image;
  final _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image, String userId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Resim yükleme hatası: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? profileImageUrl;
      if (_image != null) {
        profileImageUrl = await _uploadImage(_image!, user.uid);
      }

      // FCM token al
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': _usernameController.text.trim(),
        'name': _nameController.text.trim(),
        'birthDate': _birthDateController.text.trim(),
        'city': _cityController.text.trim(),
        'gender': _gender,
        'profileImageUrl': profileImageUrl,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken, // Yeni: FCM token
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil kaydedilemedi: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil Oluştur')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _image != null ? FileImage(_image!) : null,
                  child: _image == null
                      ? Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Kullanıcı Adı'),
                validator: (value) =>
                value!.isEmpty ? 'Kullanıcı adı gerekli' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'İsim Soyisim'),
                validator: (value) =>
                value!.isEmpty ? 'İsim soyisim gerekli' : null,
              ),
              TextFormField(
                controller: _birthDateController,
                decoration: InputDecoration(labelText: 'Doğum Tarihi (GG/AA/YYYY)'),
                validator: (value) {
                  if (value!.isEmpty) return 'Doğum tarihi gerekli';
                  final parts = value.split('/');
                  if (parts.length != 3) return 'Geçersiz format';
                  try {
                    int.parse(parts[0]);
                    int.parse(parts[1]);
                    int.parse(parts[2]);
                    return null;
                  } catch (e) {
                    return 'Geçersiz tarih';
                  }
                },
              ),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(labelText: 'Şehir'),
                validator: (value) => value!.isEmpty ? 'Şehir gerekli' : null,
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Cinsiyet'),
                value: _gender,
                items: ['Erkek', 'Kadın', 'Diğer']
                    .map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _gender = value;
                  });
                },
                validator: (value) => value == null ? 'Cinsiyet seçiniz' : null,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveProfile,
                child: Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}