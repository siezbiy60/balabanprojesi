import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<void> _acceptRequest(String otherUserId) async {
    final myId = user.uid;
    try {
      // Her iki kullanıcının friends listesine ekle ve friendRequests'ten çıkar
      await FirebaseFirestore.instance.collection('users').doc(myId).update({
        'friends': FieldValue.arrayUnion([otherUserId]),
        'friendRequests': FieldValue.arrayRemove([otherUserId]),
      });
      await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
        'friends': FieldValue.arrayUnion([myId]),
        'friendRequests': FieldValue.arrayRemove([myId]),
      });
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arkadaş eklenemedi: $e')),
      );
    }
  }

  Future<void> _rejectRequest(String otherUserId) async {
    final myId = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'friendRequests': FieldValue.arrayRemove([otherUserId]),
    });
    await FirebaseFirestore.instance.collection('users').doc(otherUserId).update({
      'friendRequests': FieldValue.arrayRemove([myId]),
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşlık İstekleri')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Yükleniyor...'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List friendRequests = data['friendRequests'] ?? [];
          if (friendRequests.isEmpty) {
            return const Center(child: Text('Hiç arkadaşlık isteğiniz yok.'));
          }
          return ListView.builder(
            itemCount: friendRequests.length,
            itemBuilder: (context, index) {
              final otherUserId = friendRequests[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const ListTile(title: Text('Kullanıcı bulunamadı'));
                  }
                  final userData = userSnap.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] ?? 'Bilinmiyor';
                  final profileImageUrl = userData['profileImageUrl'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: (profileImageUrl == null || profileImageUrl.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(username),
                    subtitle: const Text('Arkadaşlık isteği gönderdi'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Theme.of(context).colorScheme.secondary),
                          tooltip: 'Kabul Et',
                          onPressed: () => _acceptRequest(otherUserId),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                          tooltip: 'Reddet',
                          onPressed: () => _rejectRequest(otherUserId),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 