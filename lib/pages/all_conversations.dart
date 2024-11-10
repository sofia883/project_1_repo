import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'chat_page.dart';

class ConversationsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ConversationsScreen({Key? key}) : super(key: key);

  String getChatRoomId(String userId1, String userId2, String itemId) {
    return userId1.compareTo(userId2) > 0
        ? '${userId1}_${userId2}_$itemId'
        : '${userId2}_${userId1}_$itemId';
  }

  String formatTimeAgo(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 1) {
      return timeago.format(dateTime, locale: 'en_short');
    } else if (difference.inHours >= 1) {
      return timeago.format(dateTime, locale: 'en_short', allowFromNow: true);
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'a few seconds ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Center(child: Text('Please login to view conversations'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, chatSnapshot) {
          if (chatSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No conversations yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatSnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chatDoc = chatSnapshot.data!.docs[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;

              // Get the other user's ID from participants
              final participants =
                  List<String>.from(chatData['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) return SizedBox.shrink();

              // Get item details
              final itemId = chatData['itemId'] as String?;
              final itemName = chatData['itemName'] as String?;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Loading...'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final userName = userData?['name'] ??
                      userData?['username'] ??
                      'Unknown User';
                  final userAvatar = userData?['photoUrl'];
                  final lastMessage = chatData['lastMessage'] as String?;
                  final lastMessageTime =
                      chatData['lastMessageTime'] as Timestamp?;
                  final unreadCount =
                      chatData['unreadCount_$currentUserId'] ?? 0;

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userAvatar != null
                            ? NetworkImage(userAvatar)
                            : null,
                        child: userAvatar == null ? Icon(Icons.person) : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (itemName != null)
                                  Text(
                                    'Item: $itemName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (lastMessageTime != null)
                            Text(
                              formatTimeAgo(lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        if (itemId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                sellerId: otherUserId,
                                itemId: itemId,
                                itemName: itemName ?? '',
                              ),
                            ),
                          );

                          // Reset unread count
                          chatDoc.reference.update({
                            'unreadCount_$currentUserId': 0,
                          });
                        }
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
