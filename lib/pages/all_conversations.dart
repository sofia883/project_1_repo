import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';

class ConversationsListScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper method to create a more user-friendly error message
  Widget _buildErrorDisplay(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to handle the Firestore query
  Stream<QuerySnapshot> _getChatRoomsStream(String currentUserId) {
    try {
      return FirebaseFirestore.instance
          .collection('chatRooms')
          .where('participants', arrayContains: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          // Add a secondary ordering by document ID to ensure consistent ordering
          .orderBy(FieldPath.documentId, descending: true)
          .snapshots();
    } catch (e) {
      // Return an error stream that the StreamBuilder can handle
      return Stream.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Messages')),
        body: _buildErrorDisplay('Please login to view messages'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Search functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getChatRoomsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Check specifically for missing index error
            if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
              return _buildErrorDisplay(
                'Database index required. Please ask the administrator to set up the necessary index for the chat rooms collection.',
              );
            }
            return _buildErrorDisplay(
                'Error loading conversations: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final chatRooms = snapshot.data!.docs;

          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No conversations yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index].data() as Map<String, dynamic>;
              final otherUserId = (chatRoom['participants'] as List)
                  .firstWhere((id) => id != currentUserId);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    return ListTile(
                      title: Text('Error loading user'),
                      subtitle: Text('Please try again later'),
                    );
                  }

                  final userName = userSnapshot.data?.get('name') ?? 'User';
                  final lastMessage = chatRoom['lastMessage'] ?? '';
                  final lastMessageTime =
                      chatRoom['lastMessageTime'] as Timestamp?;
                  final formattedTime = lastMessageTime != null
                      ? DateFormat.yMMMd()
                          .add_jm()
                          .format(lastMessageTime.toDate())
                      : '';

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: Hero(
                        tag: 'profile_${otherUserId}',
                        child: CircleAvatar(
                          backgroundImage:
                              userSnapshot.data?.get('profileImage') != null
                                  ? NetworkImage(
                                      userSnapshot.data!.get('profileImage'))
                                  : null,
                          child: userSnapshot.data?.get('profileImage') == null
                              ? Text(userName[0].toUpperCase())
                              : null,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${chatRoom['itemName'] ?? 'Item'}: $lastMessage',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chatRoom['unreadCount'] != null &&
                              chatRoom['unreadCount'] > 0)
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${chatRoom['unreadCount']}',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              itemId: chatRoom['itemId'],
                              sellerId: otherUserId,
                              itemName: chatRoom['itemName'] ?? 'Item',
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
