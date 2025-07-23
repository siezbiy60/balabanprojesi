import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({required this.userId, Key? key}) : super(key: key);

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
  }

  Future<void> _removeFriend(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'friends': FieldValue.arrayRemove([otherUserId])
    });
    await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
      'friends': FieldValue.arrayRemove([myId])
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Arkadaşlıktan çıkarıldı.')));
  }

  Future<void> _followUser(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'following': FieldValue.arrayUnion([otherUserId])
    });
    await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
      'followers': FieldValue.arrayUnion([myId])
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takip edildi.')));
  }

  Future<void> _unfollowUser(BuildContext context, String otherUserId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myId = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'following': FieldValue.arrayRemove([otherUserId])
    });
    await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
      'followers': FieldValue.arrayRemove([myId])
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takipten çıkarıldı.')));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final myId = currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text('Kullanıcı Profili')),
      body: myId == null
          ? Center(child: Text('Giriş yapılmamış'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text('Kullanıcı bilgileri bulunamadı.'));
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final username = data['username'] as String? ?? 'Bilinmiyor';
                final name = data['name'] as String? ?? 'Bilinmiyor';
                final birthDate = data['birthDate'] as String? ?? 'Bilinmiyor';
                final city = data['city'] as String? ?? 'Bilinmiyor';
                final gender = data['gender'] as String? ?? 'Bilinmiyor';
                final profileImageUrl = data['profileImageUrl'] as String?;
                final bio = data['bio'] as String? ?? '';
                final List friends = data['friends'] ?? [];
                final List friendRequests = data['friendRequests'] ?? [];
                final List followers = data['followers'] ?? [];
                final List following = data['following'] ?? [];
                final bool isRequested = myId != null && friendRequests.contains(myId);
                final bool isFollowing = myId != null && followers.contains(myId);

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
                  builder: (context, mySnap) {
                    List myFriends = [];
                    if (mySnap.hasData && mySnap.data!.exists) {
                      final myData = mySnap.data!.data() as Map<String, dynamic>;
                      myFriends = myData['friends'] ?? [];
                    }
                    final bool isFriend = myId != null && friends.contains(myId) && myFriends.contains(widget.userId);
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(profileImageUrl)
                                  : null,
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              child: (profileImageUrl == null || profileImageUrl.isEmpty)
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
                            Text(
                              bio.isNotEmpty ? bio : 'Henüz bir açıklama eklenmemiş.',
                              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Divider(color: Theme.of(context).colorScheme.secondary),
                            SizedBox(height: 8),
                            _buildInfoRow(context, 'İsim Soyisim', name),
                            _buildInfoRow(context, 'Doğum Tarihi', birthDate),
                            _buildInfoRow(context, 'Şehir', city),
                            _buildInfoRow(context, 'Cinsiyet', gender),
                            SizedBox(height: 16),
                            if (myId != widget.userId) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: isFriend
                                        ? () => _removeFriend(context, widget.userId)
                                        : isRequested
                                            ? null
                                            : () async {
                                                await _sendFriendRequest(context, widget.userId);
                                                setState(() {});
                                              },
                                    child: Text(isFriend
                                        ? 'Arkadaşlıktan Çıkar'
                                        : isRequested
                                            ? 'İstek Gönderildi'
                                            : 'Arkadaş Ekle'),
                                  ),
                                  SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: isFollowing
                                        ? () => _unfollowUser(context, widget.userId)
                                        : () => _followUser(context, widget.userId),
                                    child: Text(isFollowing ? 'Takibi Bırak' : 'Takip Et'),
                                  ),
                                ],
                              ),
                            ],
                            // Modern Arkadaşlar Listesi
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
                                                  builder: (context) => UserProfilePage(userId: friendId),
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
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label + ':', style: TextStyle(fontWeight: FontWeight.bold)),
          Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
} 