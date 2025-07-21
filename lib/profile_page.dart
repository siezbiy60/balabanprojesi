import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profil', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}', style: TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Kullanıcı bilgileri bulunamadı.', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final username = data['username'] as String? ?? 'Bilinmiyor';
          final name = data['name'] as String? ?? 'Bilinmiyor';
          final birthDate = data['birthDate'] as String? ?? 'Bilinmiyor';
          final city = data['city'] as String? ?? 'Bilinmiyor';
          final gender = data['gender'] as String? ?? 'Bilinmiyor';
          final profileImageUrl = data['profileImageUrl'] as String?;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            child: profileImageUrl == null
                                ? Icon(Icons.person, size: 60, color: Colors.white)
                                : null,
                          ),
                          SizedBox(height: 16),
                          Text(
                            username,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 26,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Divider(color: Theme.of(context).colorScheme.secondary),
                          SizedBox(height: 8),
                          _buildInfoRow(context, 'İsim Soyisim', name),
                          _buildInfoRow(context, 'Doğum Tarihi', birthDate),
                          _buildInfoRow(context, 'Şehir', city),
                          _buildInfoRow(context, 'Cinsiyet', gender),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      textStyle: TextStyle(fontSize: 18),
                    ),
                    child: Text('Çıkış Yap'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}