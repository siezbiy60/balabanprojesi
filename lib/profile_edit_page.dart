import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileEditPage extends StatefulWidget {
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _bioController = TextEditingController();
  String? _gender;
  String? _selectedCity;
  final List<String> _cities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın',
    'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı',
    'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir',
    'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin', 'İstanbul',
    'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya',
    'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
    'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ',
    'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak',
    'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan',
    'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
  ];
  File? _image;
  String? _profileImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _birthDateController.text = data['birthDate'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _gender = data['gender'] ?? null;
      _selectedCity = data['city'] ?? null;
      _profileImageUrl = data['profileImageUrl'];
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
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

  Future<File?> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      file.absolute.path + '_compressed.jpg',
      quality: 70,
      minWidth: 400,
      minHeight: 400,
    );
    if (result == null) return null;
    return File(result.path);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    final user = FirebaseAuth.instance.currentUser!;
    String? imageUrl = _profileImageUrl;
    if (_image != null) {
      File uploadFile = _image!;
      if (!kIsWeb) {
        final compressed = await _compressImage(_image!);
        if (compressed != null) uploadFile = compressed;
      }
      imageUrl = await _uploadImage(uploadFile, user.uid);
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': _nameController.text.trim(),
      'birthDate': _birthDateController.text.trim(),
      'city': _selectedCity,
      'gender': _gender,
      'bio': _bioController.text.trim(),
      'profileImageUrl': imageUrl,
    });
    setState(() { _isLoading = false; });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profili Düzenle')),
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
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                          ? NetworkImage(_profileImageUrl!) as ImageProvider
                          : null,
                  child: (_image == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                      ? Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'İsim Soyisim'),
                validator: (value) => value!.isEmpty ? 'İsim soyisim gerekli' : null,
              ),
              TextFormField(
                controller: _birthDateController,
                decoration: InputDecoration(labelText: 'Doğum Tarihi (GG/AA/YYYY)'),
                readOnly: true,
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _birthDateController.text =
                        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                  }
                },
                validator: (value) => value!.isEmpty ? 'Doğum tarihi gerekli' : null,
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Şehir'),
                value: _selectedCity,
                items: _cities.map((city) => DropdownMenuItem(
                  value: city,
                  child: Text(city),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Şehir seçiniz' : null,
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
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(labelText: 'Hakkında (Bio)'),
                maxLines: 2,
                maxLength: 120,
                validator: (value) => value!.length > 120 ? 'En fazla 120 karakter' : null,
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