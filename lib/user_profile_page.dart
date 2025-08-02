import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({required this.userId, super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Future<void> _sendFriendRequest(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    // Sadece alıcının friendRequests listesine ekle, merge ile alan yoksa oluştur
    await FirebaseFirestore.instance.collection('users').doc(otherUserId).set({
      'friendRequests': FieldValue.arrayUnion([myId])
    }, SetOptions(merge: true));
    // Bildirim gönder
    final receiverDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
    final fcmToken = receiverDoc.data()?['fcmToken'];
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'token': fcmToken,
        'title': 'Arkadaşlık İsteği',
        'body': '${user.displayName ?? user.email ?? "Bir kullanıcı"} sana arkadaşlık isteği gönderdi.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    setState(() {});
  }

  Future<void> _removeFriend(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    try {
      await FirebaseFirestore.instance.collection('users').doc(myId).update({
        'friends': FieldValue.arrayRemove([otherUserId])
      });
    } catch (_) {}
    try {
      await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
        'friends': FieldValue.arrayRemove([myId])
      });
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arkadaşlıktan çıkarıldı.')));
    setState(() {});
  }

  Future<void> _cancelFriendRequest(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    try {
      await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
        'friendRequests': FieldValue.arrayRemove([myId])
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arkadaşlık isteği iptal edildi.')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İstek iptal edilemedi: $e')));
    }
  }

  Future<void> _followUser(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    try {
      // Kendi following listesine ekle, alan yoksa oluştur
      await FirebaseFirestore.instance.collection('users').doc(myId).set({
        'following': FieldValue.arrayUnion([otherUserId])
      }, SetOptions(merge: true));
      // Karşı tarafın followers listesine ekle, alan yoksa oluştur
      await FirebaseFirestore.instance.collection('users').doc(otherUserId).set({
        'followers': FieldValue.arrayUnion([myId])
      }, SetOptions(merge: true));
      // Bildirim gönder
      final receiverDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
      final fcmToken = receiverDoc.data()?['fcmToken'];
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'token': fcmToken,
          'title': 'Yeni Takipçi',
          'body': '${user.displayName ?? user.email ?? "Bir kullanıcı"} seni takip etmeye başladı.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Takip edilemedi: $e')),
      );
    }
  }

  Future<void> _unfollowUser(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    try {
      // Kendi following listesinden çıkar
      await FirebaseFirestore.instance.collection('users').doc(myId).update({
        'following': FieldValue.arrayRemove([otherUserId])
      });
      // Karşı tarafın followers listesinden çıkar
      await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
        'followers': FieldValue.arrayRemove([myId])
      });
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Takipten çıkarılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myId = currentUser?.uid;
    final isOwnProfile = myId == widget.userId;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kullanıcı Profili'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (myId != null && myId != widget.userId)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final List friends = data['friends'] ?? [];
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
                  builder: (context, mySnap) {
                    List myFriends = [];
                    if (mySnap.hasData && mySnap.data!.exists) {
                      final myData = mySnap.data!.data() as Map<String, dynamic>;
                      myFriends = myData['friends'] ?? [];
                    }
                    final bool isFriend = friends.contains(myId) && myFriends.contains(widget.userId);
                    if (!isFriend) return const SizedBox();
                    return PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'remove') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Arkadaşlıktan Çıkar'),
                              content: const Text('Bu kişiyi arkadaşlıktan çıkarmak istediğine emin misin?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Evet, Çıkar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _removeFriend(context, widget.userId);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Arkadaşlıktan Çıkar', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: myId == null
          ? const Center(child: Text('Giriş yapılmamış'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Kullanıcı bilgileri bulunamadı.'));
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final username = data['username'] as String? ?? 'Bilinmiyor';
                final name = data['name'] as String? ?? 'Bilinmiyor';
                final birthDate = data['birthDate'] as String? ?? 'Bilinmiyor';
                final city = data['city'] as String? ?? 'Bilinmiyor';
                final gender = data['gender'] as String? ?? 'Bilinmiyor';
                final profileImageUrl = data['profileImageUrl'] as String?;
                final bio = data['bio'] as String? ?? '';
                
                // Debug bilgisi
                print('Profil verileri yüklendi:');
                print('Username: $username');
                print('Name: $name');
                print('City: $city');
                print('ProfileImageUrl: $profileImageUrl');
                print('Bio: $bio');
                final List friends = data['friends'] ?? [];
                final List friendRequests = data['friendRequests'] ?? [];
                final List followers = data['followers'] ?? [];
                final List following = data['following'] ?? [];
                final bool isRequested = friendRequests.contains(myId);
                final bool isFollowing = followers.contains(myId);

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
                  builder: (context, mySnap) {
                    List myFriends = [];
                    if (mySnap.hasData && mySnap.data!.exists) {
                      final myData = mySnap.data!.data() as Map<String, dynamic>;
                      myFriends = myData['friends'] ?? [];
                    }
                    bool isFriend = false;
                    isFriend = friends.contains(myId) && myFriends.contains(widget.userId);
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
                                  // Profile Image
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
                                _buildStat('Takipçi', followers.length, () {
                                  Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute(
                                      builder: (context) => FollowersPage(
                                        followers: followers,
                                        isOwnProfile: isOwnProfile,
                                        myId: myId,
                                      ),
                                    ),
                                  );
                                }),
                                _buildStat('Takip', following.length, () {
                                  Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute(
                                      builder: (context) => FollowingPage(
                                        following: following,
                                        isOwnProfile: isOwnProfile,
                                        myId: myId,
                                      ),
                                    ),
                                  );
                                }),
                                _buildStat('Arkadaşlar', friends.length, () {
                                  Navigator.of(context, rootNavigator: true).push(
                                    MaterialPageRoute(
                                      builder: (context) => FriendsPage(
                                        friends: friends,
                                        isOwnProfile: isOwnProfile,
                                        myId: myId,
                                      ),
                                    ),
                                  );
                                }),
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

                          // Action Buttons
                          if (myId != widget.userId) ...[
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(
                                              receiverId: widget.userId,
                                              receiverName: username,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.message, size: 16),
                                      label: const Text('Mesaj', style: TextStyle(fontSize: 10)),
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
                                    child: ElevatedButton(
                                      onPressed: isFriend
                                          ? () => _removeFriend(context, widget.userId)
                                          : isRequested
                                              ? () => _cancelFriendRequest(context, widget.userId)
                                              : () async {
                                                  await _sendFriendRequest(context, widget.userId);
                                                  setState(() {});
                                                },
                                      child: Text(
                                        isFriend ? 'Arkadaşlıktan Çıkar' : isRequested ? 'İptal' : 'Arkadaş Ekle',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFriend ? Colors.red : Colors.green,
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
                                    child: ElevatedButton(
                                      onPressed: isFollowing
                                          ? () => _unfollowUser(context, widget.userId)
                                          : () => _followUser(context, widget.userId),
                                      child: Text(
                                        isFollowing ? 'Takibi Bırak' : 'Takip Et',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing ? Colors.orange : Colors.purple,
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
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildStat(String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
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
}

// Takipçi listesi sayfası
class FollowersPage extends StatelessWidget {
  final List followers;
  final bool isOwnProfile;
  final String? myId;
  const FollowersPage({required this.followers, this.isOwnProfile = false, this.myId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Takipçiler'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: followers.isEmpty
          ? const Center(child: Text('Hiç takipçin yok.'))
          : ListView.builder(
              itemCount: followers.length,
              itemBuilder: (context, index) {
                final followerId = followers[index];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(followerId).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const ListTile(title: Text('Kullanıcı bulunamadı'));
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final username = data['username'] ?? 'Bilinmiyor';
                    final profileImageUrl = data['profileImageUrl'];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? CachedNetworkImageProvider(profileImageUrl)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(username, style: const TextStyle(color: Colors.black87)),
                        trailing: isOwnProfile && myId != null
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                tooltip: 'Takipçiden Çıkar',
                                onPressed: () async {
                                  // Kendi profilindeysen takipçiden çıkar
                                  await FirebaseFirestore.instance.collection('users').doc(myId).update({
                                    'followers': FieldValue.arrayRemove([followerId])
                                  });
                                  // İstersen karşı tarafın following listesinden de çıkarabilirsin
                                  await FirebaseFirestore.instance.collection('users').doc(followerId).update({
                                    'following': FieldValue.arrayRemove([myId])
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takipçi çıkarıldı.')));
                                },
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(userId: followerId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// Arkadaşlar listesi sayfası
class FriendsPage extends StatelessWidget {
  final List friends;
  final bool isOwnProfile;
  final String? myId;
  const FriendsPage({required this.friends, this.isOwnProfile = false, this.myId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Arkadaşlar'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: friends.isEmpty
          ? const Center(child: Text('Hiç arkadaşın yok.'))
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friendId = friends[index];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const ListTile(title: Text('Kullanıcı bulunamadı'));
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final username = data['username'] ?? 'Bilinmiyor';
                    final profileImageUrl = data['profileImageUrl'];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? CachedNetworkImageProvider(profileImageUrl)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(username, style: const TextStyle(color: Colors.black87)),
                        trailing: isOwnProfile && myId != null
                            ? IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.red),
                                tooltip: 'Arkadaşlıktan Çıkar',
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('users').doc(myId).update({
                                    'friends': FieldValue.arrayRemove([friendId])
                                  });
                                  await FirebaseFirestore.instance.collection('users').doc(friendId).update({
                                    'friends': FieldValue.arrayRemove([myId])
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arkadaşlıktan çıkarıldı.')));
                                },
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(userId: friendId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// Takip edilenler (following) listesi sayfası
class FollowingPage extends StatelessWidget {
  final List following;
  final bool isOwnProfile;
  final String? myId;
  const FollowingPage({required this.following, this.isOwnProfile = false, this.myId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Takip Edilenler'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: following.isEmpty
          ? const Center(child: Text('Hiç kimseyi takip etmiyorsun.'))
          : ListView.builder(
              itemCount: following.length,
              itemBuilder: (context, index) {
                final followingId = following[index];
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(followingId).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const ListTile(title: Text('Kullanıcı bulunamadı'));
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final username = data['username'] ?? 'Bilinmiyor';
                    final profileImageUrl = data['profileImageUrl'];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? CachedNetworkImageProvider(profileImageUrl)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(username, style: const TextStyle(color: Colors.black87)),
                        trailing: isOwnProfile && myId != null
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                tooltip: 'Takipten Çıkar',
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('users').doc(myId).update({
                                    'following': FieldValue.arrayRemove([followingId])
                                  });
                                  await FirebaseFirestore.instance.collection('users').doc(followingId).update({
                                    'followers': FieldValue.arrayRemove([myId])
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takipten çıkarıldı.')));
                                },
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(userId: followingId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
} 