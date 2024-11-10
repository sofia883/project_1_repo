import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ChatScreen extends StatefulWidget {
  final String itemId;
  final String sellerId;
  final String itemName;
  final String sellerName;

  const ChatScreen({
    Key? key,
    required this.itemId,
    required this.sellerId,
    required this.itemName,
    required this.sellerName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  late String chatRoomId;
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _createChatRoom();
    _setupMessagesStream();
  }

  Future<void> _setupNotifications() async {
    // Request permission for notifications
    FirebaseMessaging.instance.requestPermission();
    
    // Configure local notifications
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _notificationsPlugin.initialize(initializationSettings);

    // Handle FCM messages when app is in background
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message.notification?.title ?? '', message.notification?.body ?? '');
    });
  }

  Future<void> _showNotification(String title, String body) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_channel',
        'Chat Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  void _createChatRoom() {
    // Create a unique chat room ID by combining buyer and seller IDs
    final buyerId = _auth.currentUser!.uid;
    final participants = [buyerId, widget.sellerId]..sort();
    chatRoomId = '${participants[0]}_${participants[1]}_${widget.itemId}';
  }

  void _setupMessagesStream() {
    _messagesStream = _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    final currentUser = _auth.currentUser!;
    final timestamp = FieldValue.serverTimestamp();

    // Store the message in Firestore
    await _firestore.collection('chats').doc(chatRoomId).collection('messages').add({
      'senderId': currentUser.uid,
      'senderName': currentUser.displayName ?? 'Anonymous',
      'message': message,
      'timestamp': timestamp,
    });

    // Update chat room metadata
    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': message,
      'lastMessageTime': timestamp,
      'participants': [currentUser.uid, widget.sellerId],
      'itemId': widget.itemId,
      'itemName': widget.itemName,
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Send FCM notification to the recipient
    await _sendNotification(
      recipientId: widget.sellerId,
      title: 'New message from ${currentUser.displayName}',
      body: message,
    );
  }

  Future<void> _sendNotification({
    required String recipientId,
    required String title,
    required String body,
  }) async {
    // Get recipient's FCM token from Firestore
    final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
    final fcmToken = recipientDoc.data()?['fcmToken'];

    if (fcmToken != null) {
      // Send FCM notification using Cloud Functions or your server
      // This is just a placeholder - you'll need to implement the actual sending
      print('Sending notification to token: $fcmToken');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sellerName),
            Text(
              widget.itemName,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMyMessage = message['senderId'] == _auth.currentUser?.uid;

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMyMessage ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['senderName'] ?? 'Anonymous',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(message['message'] ?? ''),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}