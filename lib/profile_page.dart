import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'profile_edit_page.dart';
import 'user_profile_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    
    // Debug: Kullanıcı bilgilerini kontrol et
    print('=== PROFILE PAGE DEBUG ===');
    print('Current User ID: ${user.uid}');
    print('Current User Email: ${user.email}');
    print('Current User DisplayName: ${user.displayName}');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditPage(),
                ),
              );
              if (result == true) {
                // StreamBuilder otomatik olarak yenilenecek
              }
            },
            tooltip: 'Profili Düzenle',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          print('=== STREAMBUILDER DEBUG ===');
          print('Connection State: ${snapshot.connectionState}');
          print('Has Data: ${snapshot.hasData}');
          print('Has Error: ${snapshot.hasError}');
          if (snapshot.hasError) {
            print('Error: ${snapshot.error}');
          }
          if (snapshot.hasData) {
            print('Data Exists: ${snapshot.data!.exists}');
            if (snapshot.data!.exists) {
              print('Raw Data: ${snapshot.data!.data()}');
            }
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text('Hata: ${snapshot.error}'),
                ],
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text('Kullanıcı bilgileri bulunamadı.'),
                  SizedBox(height: 8),
                  Text('Firestore\'da kullanıcı dokümanı yok.'),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          // Debug bilgisi
          print('=== PROFILE DATA DEBUG ===');
          print('Data: $data');
          
          final username = data['username'] as String? ?? 'Bilinmiyor';
          final name = data['name'] as String? ?? 'Bilinmiyor';
          final birthDate = data['birthDate'] as String? ?? 'Bilinmiyor';
          final city = data['city'] as String? ?? 'Bilinmiyor';
          final gender = data['gender'] as String? ?? 'Bilinmiyor';
          final profileImageUrl = data['profileImageUrl'] as String?;
          final bio = data['bio'] as String? ?? '';
          final followers = (data['followers'] ?? []) as List;
          final following = (data['following'] ?? []) as List;
          final friends = (data['friends'] ?? []) as List;

          print('Username: $username');
          print('Name: $name');
          print('City: $city');
          print('Gender: $gender');
          print('BirthDate: $birthDate');
          print('Bio: $bio');
          print('ProfileImageUrl: $profileImageUrl');
          print('Followers count: ${followers.length}');
          print('Following count: ${following.length}');
          print('Friends count: ${friends.length}');

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Section with Gradient
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blue, Colors.blueAccent],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Profile Image with Edit Icon
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 70,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 65,
                                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(profileImageUrl)
                                      : null,
                                  backgroundColor: Colors.grey[300],
                                  child: profileImageUrl == null || profileImageUrl.isEmpty
                                      ? const Icon(Icons.person, size: 70, color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProfileEditPage(),
                                    ),
                                  );
                                  if (result == true) {
                                    // StreamBuilder otomatik olarak yenilenecek
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Name and Username
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Bio
                        if (bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              bio,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Stats Section
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Arkadaşlar', friends.length, Icons.people),
                      _buildStat('Takipçi', followers.length, Icons.favorite),
                      _buildStat('Takip', following.length, Icons.person_add),
                    ],
                  ),
                ),

                // Info Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kişisel Bilgiler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('İsim Soyisim', name, Icons.person),
                      _buildInfoRow('Kullanıcı Adı', '@$username', Icons.alternate_email),
                      _buildInfoRow('Doğum Tarihi', birthDate, Icons.cake),
                      _buildInfoRow('Şehir', city, Icons.location_city),
                      _buildInfoRow('Cinsiyet', gender, Icons.person_outline),
                    ],
                  ),
                ),

                // Friends Section
                if (friends.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Arkadaşlar (${friends.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              final friendId = friends[index];
                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(friendId)
                                    .get(),
                                builder: (context, friendSnap) {
                                  if (!friendSnap.hasData || !friendSnap.data!.exists) {
                                    return _buildFriendItem(
                                      '?',
                                      null,
                                      () {},
                                    );
                                  }
                                  final friendData = friendSnap.data!.data() as Map<String, dynamic>;
                                  final friendName = friendData['name'] as String? ?? 'Bilinmiyor';
                                  final friendPhoto = friendData['profileImageUrl'] as String?;
                                  return _buildFriendItem(
                                    friendName,
                                    friendPhoto,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfilePage(userId: friendId),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileEditPage(),
                              ),
                            );
                            if (result == true) {
                              // StreamBuilder otomatik olarak yenilenecek
                            }
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Profili Düzenle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Çıkış Yap'),
                                content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('İptal'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      FirebaseAuth.instance.signOut();
                                      Navigator.pushReplacementNamed(context, '/login');
                                    },
                                    child: const Text('Çıkış Yap'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Çıkış Yap'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(String name, String? photoUrl, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              backgroundColor: Colors.grey[300],
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 25, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 50,
              child: Text(
                name,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 