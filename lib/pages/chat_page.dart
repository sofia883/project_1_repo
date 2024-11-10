// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:project_1/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:project_1/main.dart';
class ChatScreen extends StatefulWidget {
  final String sellerId;
  final String itemId;
  final String itemName;

  const ChatScreen({
    Key? key,
    required this.sellerId,
    required this.itemId,
    required this.itemName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String chatRoomId;
  late String currentUserId;
  final messagingService = FirebaseMessagingService();
  // await messagingService.initialize();
  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser!.uid;
    // Create a unique chat room ID combining buyer and seller IDs
    chatRoomId = getChatRoomId(currentUserId, widget.sellerId);
    setupPushNotifications();
    markMessagesAsRead();
  }

  String getChatRoomId(String userId1, String userId2) {
    // Create a consistent chat room ID regardless of who initiates the chat
    return userId1.compareTo(userId2) > 0
        ? '${userId1}_${userId2}_${widget.itemId}'
        : '${userId2}_${userId1}_${widget.itemId}';
  }

  Future<void> setupPushNotifications() async {
    // Request permission for notifications
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    // Get the token for this device
    String? token = await messaging.getToken();

    // Store the token in Firestore
    if (token != null) {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({'fcmToken': token});
    }

    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Navigate to chat screen if needed
      if (message.data['chatRoomId'] == chatRoomId) {
        // Navigation logic here if needed
      }
    });
  }

  Future<void> showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await FlutterLocalNotificationsPlugin().show(
      0,
      message.notification?.title ?? 'New Message',
      message.notification?.body,
      details,
      payload: chatRoomId,
    );
  }

  Future<void> markMessagesAsRead() async {
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'isRead': true});
      }
    });
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final timestamp = FieldValue.serverTimestamp();
    final messageData = {
      'senderId': currentUserId,
      'receiverId': widget.sellerId,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
    };

    // Add message to Firestore
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // Update last message in chat room
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': message,
      'lastMessageTime': timestamp,
      'participants': [currentUserId, widget.sellerId],
      'itemId': widget.itemId,
      'itemName': widget.itemName,
    });

    // Send push notification
    final receiverDoc =
        await _firestore.collection('users').doc(widget.sellerId).get();

    if (receiverDoc.exists) {
      final fcmToken = receiverDoc.data()?['fcmToken'];
      if (fcmToken != null) {
        // Inside sendMessage method, before sending the push notification:
        await _firestore.collection('chats').doc(chatRoomId).update({
          'unreadCount_${widget.sellerId}': FieldValue.increment(1),
        });
        await messagingService.sendNotification(
  recipientId: widget.sellerId,
  title: 'New message from ${currentUserId}',
  body: message,
  data: {
    'chatRoomId': chatRoomId,
    'itemId': widget.itemId,
    'type': 'chat_message',
  },
);
      }
    }

    _messageController.clear();
  }

  Future<void> sendPushNotification(
      String fcmToken, String title, String body) async {
    // Implement your push notification logic here
    // You can use Firebase Cloud Functions or a server endpoint
  }

  Future<void> showMessageOptions(
      BuildContext context, DocumentSnapshot messageDoc) async {
    final messageText = messageDoc['message'];
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: messageText));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete for Me'),
              onTap: () async {
                await messageDoc.reference.delete();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever),
              title: Text('Delete for Everyone'),
              onTap: () async {
                if (messageDoc['senderId'] == currentUserId) {
                  await messageDoc.reference.delete();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('You can only delete your own messages')),
                  );
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel),
              title: Text('Cancel'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.itemName),
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.sellerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                return Text(
                  userData?['name'] ?? 'User',
                  style: TextStyle(fontSize: 12),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMyMessage = message['senderId'] == currentUserId;

                    return GestureDetector(
                      onLongPress: () =>
                          showMessageOptions(context, messages[index]),
                      child: MessageBubble(
                        message: message['message'],
                        isMyMessage: isMyMessage,
                        timestamp: message['timestamp'],
                        isRead: message['isRead'],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, offset: Offset(0, -1), blurRadius: 4)
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMyMessage;
  final Timestamp? timestamp;
  final bool isRead;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMyMessage,
    this.timestamp,
    required this.isRead,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMyMessage ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp != null
                            ? timeago.format(timestamp!.toDate())
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMyMessage ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      if (isMyMessage) ...[
                        SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) SizedBox(width: 40),
        ],
      ),
    );
  }
}
