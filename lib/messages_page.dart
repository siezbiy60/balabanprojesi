import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'chat_page.dart';

class MessagesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    print('MessagesPage Kullanıcı ID: ${user.uid}');

    final sentMessagesStream = FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    final receivedMessagesStream = FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();

    final mergedStream = CombineLatestStream.list<QuerySnapshot<Map<String, dynamic>>>([
      sentMessagesStream,
      receivedMessagesStream,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mesajlar', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
        stream: mergedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Mesajlar sayfası hatası: ${snapshot.error.toString()}');
            return Center(child: Text('Hata: ${snapshot.error.toString()}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty || snapshot.data!.every((qs) => qs.docs.isEmpty)) {
            print('Mesaj bulunamadı: Veri yok veya boş');
            return Center(child: Text('Mesaj bulunamadı.'));
          }

          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> latestMessages = {};
          for (var snapshot in snapshot.data!) {
            for (var doc in snapshot.docs) {
              final messageData = doc.data();
              final senderId = messageData['senderId'] as String?;
              final receiverId = messageData['receiverId'] as String?;
              if (senderId == null || receiverId == null) continue;

              final otherUserId = senderId == user.uid ? receiverId : senderId;
              final currentTimestamp = messageData['timestamp'] as Timestamp?;
              final existingMessage = latestMessages[otherUserId];
              final existingTimestamp = existingMessage?.data()['timestamp'] as Timestamp?;

              if (currentTimestamp != null &&
                  (existingTimestamp == null || currentTimestamp.compareTo(existingTimestamp) > 0)) {
                latestMessages[otherUserId] = doc;
              }
            }
          }

          final messages = latestMessages.values.toList()
            ..sort((a, b) {
              final aTimestamp = a.data()['timestamp'] as Timestamp?;
              final bTimestamp = b.data()['timestamp'] as Timestamp?;
              if (aTimestamp == null || bTimestamp == null) return 0;
              return bTimestamp.compareTo(aTimestamp);
            });

          print('Çekilen sohbet sayısı: ${messages.length}');
          if (messages.isEmpty) {
            print('Mesaj bulunamadı: Gruplandırılmış veri yok');
            return Center(child: Text('Mesaj bulunamadı.'));
          }

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final messageData = messages[index].data();
              final senderId = messageData['senderId'] as String?;
              final receiverId = messageData['receiverId'] as String?;
              final text = messageData['text'] as String?;
              final timestamp = messageData['timestamp'] as Timestamp?;
              if (senderId == null || receiverId == null || text == null) {
                print('Eksik veri: $messageData');
                return const SizedBox.shrink();
              }
              final isSentByMe = senderId == user.uid;
              final otherUserId = isSentByMe ? receiverId : senderId;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  String username = 'Bilinmiyor';
                  String? profilePictureUrl;
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (userData != null) {
                      username = userData['username'] as String? ?? 'Bilinmiyor';
                      profilePictureUrl = userData['profilePictureUrl'] as String?;
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: profilePictureUrl != null ? NetworkImage(profilePictureUrl) : null,
                        child: profilePictureUrl == null
                            ? Text(username[0], style: TextStyle(color: Theme.of(context).colorScheme.onPrimary))
                            : null,
                      ),
                      title: Text(username),
                      subtitle: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timestamp != null ? DateFormat('HH:mm, dd MMM').format(timestamp.toDate()) : 'Bilinmiyor',
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                            onPressed: () async {
                              final batch = FirebaseFirestore.instance.batch();
                              final relatedMessages = await FirebaseFirestore.instance
                                  .collection('messages')
                                  .where('senderId', isEqualTo: user.uid)
                                  .where('receiverId', isEqualTo: otherUserId)
                                  .get();
                              final relatedMessages2 = await FirebaseFirestore.instance
                                  .collection('messages')
                                  .where('receiverId', isEqualTo: user.uid)
                                  .where('senderId', isEqualTo: otherUserId)
                                  .get();
                              for (var doc in relatedMessages.docs) {
                                batch.delete(doc.reference);
                              }
                              for (var doc in relatedMessages2.docs) {
                                batch.delete(doc.reference);
                              }
                              await batch.commit();
                              print('Sohbet silindi: $otherUserId');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$username ile sohbet silindi.')),
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              receiverId: otherUserId,
                              receiverUsername: username,
                            ),
                          ),
                        );
                      },
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