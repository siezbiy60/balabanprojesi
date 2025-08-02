import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({Key? key}) : super(key: key);

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _selectedCity;
  String? _gender;
  bool _isLoading = false;

  final List<String> _cities = [
    'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Adana', 'Antalya', 'Konya', 'Gaziantep',
    'Şanlıurfa', 'Kocaeli', 'Mersin', 'Diyarbakır', 'Kayseri', 'Samsun', 'Sakarya',
    'Eskişehir', 'Trabzon', 'Erzurum', 'Malatya', 'Van', 'Ordu', 'Denizli', 'Balıkesir',
    'Manisa', 'Kahramanmaraş', 'Aydın', 'Tekirdağ', 'Hatay', 'Çorum', 'Afyon', 'Elazığ',
    'Sivas', 'Kütahya', 'Çanakkale', 'Aksaray', 'Isparta', 'Uşak', 'Edirne', 'Tokat',
    'Zonguldak', 'Kırıkkale', 'Batman', 'Kırşehir', 'Kastamonu', 'Yozgat', 'Karaman',
    'Kars', 'Amasya', 'Nevşehir', 'Rize', 'Bolu', 'Bilecik', 'Düzce', 'Osmaniye',
    'Yalova', 'Karabük', 'Kilis', 'Bartın', 'Ardahan', 'Iğdır', 'Sinop', 'Bayburt',
    'Gümüşhane', 'Tunceli', 'Hakkari', 'Şırnak', 'Artvin', 'Bingöl', 'Bitlis', 'Muş',
    'Ağrı', 'Niğde', 'Giresun', 'Çankırı', 'Burdur', 'Erzincan', 'Aksaray', 'Kilis',
    'Aksaray', 'Kilis', 'Osmaniye', 'Düzce'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final fullName = '${_nameController.text.trim()} ${_surnameController.text.trim()}';
      
      // Debug bilgisi
      print('=== PROFILE SETUP DEBUG ===');
      print('User ID: ${user.uid}');
      print('Full Name: $fullName');
      print('Username: ${_usernameController.text.trim()}');
      print('City: $_selectedCity');
      print('Gender: $_gender');
      print('Bio: ${_bioController.text.trim()}');
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': fullName,
        'username': _usernameController.text.trim(),
        'city': _selectedCity,
        'gender': _gender,
        'bio': _bioController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': true,
        'friends': [],
        'followers': [],
        'following': [],
        'friendRequests': [],
      }, SetOptions(merge: true));
      
      print('Profil başarıyla kaydedildi!');
      
      setState(() { _isLoading = false; });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      print('Profil kaydetme hatası: $e');
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil kaydedilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Profil Kurulumu'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Başlık
                    Text(
                      'Profilinizi Tamamlayın',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Diğer kullanıcılar sizi daha iyi tanıyabilir',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Ad
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Ad *',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Ad giriniz' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Soyad
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _surnameController,
                        decoration: InputDecoration(
                          labelText: 'Soyad *',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Soyad giriniz' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Kullanıcı Adı
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı *',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.alternate_email, color: Theme.of(context).colorScheme.primary),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Kullanıcı adı giriniz' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Şehir
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCity,
                        items: _cities.map((city) => DropdownMenuItem(
                          value: city,
                          child: Text(city),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedCity = value),
                        decoration: InputDecoration(
                          labelText: 'Şehir *',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.location_city, color: Theme.of(context).colorScheme.primary),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Şehir seçiniz' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Cinsiyet
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        items: ['Erkek', 'Kadın', 'Diğer'].map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        )).toList(),
                        onChanged: (value) => setState(() => _gender = value),
                        decoration: InputDecoration(
                          labelText: 'Cinsiyet *',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Cinsiyet seçiniz' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Biyografi
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _bioController,
                        decoration: InputDecoration(
                          labelText: 'Biyografi',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                        ),
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Kaydet Butonu
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Profili Kaydet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
