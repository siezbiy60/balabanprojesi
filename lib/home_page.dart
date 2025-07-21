import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text('BalabanProje', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircleAvatar(radius: 20, child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final profileImageUrl = data['profileImageUrl'] as String?;

              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                  child: profileImageUrl == null ? Icon(Icons.person, color: Colors.white) : null,
                ),
              );
            },
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Kullanıcılar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 24,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('HomePage kullanıcı hatası: ${snapshot.error.toString()}');
                  return Center(child: Text('Hata: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print('HomePage: Kullanıcı bulunamadı');
                  return Center(child: Text('Kullanıcı bulunamadı.'));
                }

                final users = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    if (userId == user.uid) return SizedBox.shrink();
                    final username = userData['username'] as String? ?? 'Bilinmiyor';
                    final birthDate = userData['birthDate'] as String? ?? 'Bilinmiyor';
                    final city = userData['city'] as String? ?? 'Bilinmiyor';
                    final profileImageUrl = userData['profileImageUrl'] as String?;

                    int? age;
                    try {
                      final parts = birthDate.split('/');
                      if (parts.length == 3) {
                        final day = int.parse(parts[0]);
                        final month = int.parse(parts[1]);
                        final year = int.parse(parts[2]);
                        final birth = DateTime(year, month, day);
                        final now = DateTime.now();
                        age = now.year - birth.year;
                        if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
                          age--;
                        }
                      }
                    } catch (e) {
                      age = null;
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                          child: profileImageUrl == null ? Icon(Icons.person, color: Colors.white) : null,
                        ),
                        title: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Yaş: ${age ?? "Bilinmiyor"} • Şehir: $city'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  receiverId: userId,
                                  receiverUsername: username,
                                ),
                              ),
                            );
                          },
                          child: Text('Sohbet Et'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
            },
            label: Text('Profil'),
            icon: Icon(Icons.person),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
          SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .where('receiverId', isEqualTo: user.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              print('Okunmamış mesaj sayısı: $unreadCount');
              return Stack(
                children: [
                  FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => MessagesPage()));
                    },
                    label: Text('Mesajlar'),
                    icon: Icon(Icons.message),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}