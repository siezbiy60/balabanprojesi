import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata:  {snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
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
          final bio = data['bio'] as String? ?? '';
          final followers = (data['followers'] ?? []) as List;
          final following = (data['following'] ?? []) as List;
          final friends = (data['friends'] ?? []) as List;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profil Kartı
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(profileImageUrl)
                                    : null,
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                child: profileImageUrl == null || profileImageUrl.isEmpty
                                    ? Icon(Icons.person, size: 60, color: Colors.white)
                                    : null,
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.edit, size: 22, color: Theme.of(context).colorScheme.primary),
                                    tooltip: 'Profili Düzenle',
                                    onPressed: () => Navigator.pushNamed(context, '/profile_edit'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            username,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            bio.isNotEmpty ? bio : 'Henüz bir açıklama eklenmemiş.',
                            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('Arkadaşlar', friends.length),
                              _buildStat('Takipçi', followers.length),
                              _buildStat('Takip', following.length),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Bilgiler Kartı
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          _buildInfoRow(context, 'İsim Soyisim', name),
                          _buildInfoRow(context, 'Doğum Tarihi', birthDate),
                          _buildInfoRow(context, 'Şehir', city),
                          _buildInfoRow(context, 'Cinsiyet', gender),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Arkadaşlar Listesi
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Arkadaşlar (${friends.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  SizedBox(height: 8),
                  if (friends.isEmpty)
                    Center(
                      child: Text('Henüz arkadaş yok', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: friends.length,
                      separatorBuilder: (context, i) => SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final friendId = friends[i];
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                          builder: (context, friendSnap) {
                            if (!friendSnap.hasData || !friendSnap.data!.exists) {
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  leading: CircleAvatar(radius: 28, child: Icon(Icons.person)),
                                  title: Text('?', style: TextStyle(fontSize: 16)),
                                  subtitle: Text('Kullanıcı bulunamadı'),
                                ),
                              );
                            }
                            final friendData = friendSnap.data!.data() as Map<String, dynamic>;
                            final friendName = friendData['username'] ?? 'Bilinmiyor';
                            final friendPhoto = friendData['profileImageUrl'] ?? '';
                            return Card(
                              elevation: 4,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundImage: friendPhoto.isNotEmpty ? CachedNetworkImageProvider(friendPhoto) : null,
                                  child: friendPhoto.isEmpty ? Icon(Icons.person, size: 28) : null,
                                ),
                                title: Text(friendName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfilePage(), // Kendi profilin için UserProfilePage yerine ProfilePage açılır
                                      ),
                                    );
                                  },
                                  child: Text('Profili Gör'),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        icon: Icon(Icons.logout),
                        label: Text('Çıkış Yap'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          textStyle: TextStyle(fontSize: 16),
                          backgroundColor: Colors.redAccent,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/profile_edit');
                        },
                        icon: Icon(Icons.edit),
                        label: Text('Profili Düzenle'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          textStyle: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }
}