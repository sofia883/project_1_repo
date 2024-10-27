import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String itemId;
  final String sellerId;
  final String itemName;

  const ChatScreen({
    Key? key,
    required this.itemId,
    required this.sellerId,
    required this.itemName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  String? currentUserId;
  String? _fcmToken;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      // Ensure user is authenticated
      User? user = _auth.currentUser;
      if (user == null) {
        // Handle authentication if needed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to continue')),
        );
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        currentUserId = user.uid;
      });

      // Initialize chat and messaging
      await _initializeFCM();
      await _validateAndCreateChat();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing: $e')),
      );
    }
  }

  Future<void> _initializeFCM() async {
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcmToken = await _fcm.getToken();

      if (_fcmToken != null && currentUserId != null) {
        // Create user document with proper security rules
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({
          'fcmToken': _fcmToken,
          'lastUpdated': FieldValue.serverTimestamp(),
          'userId': currentUserId, // Add user ID for security rules
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error initializing FCM: $e");
    }
  }

  Future<void> _validateAndCreateChat() async {
    if (currentUserId == null) return;

    if (currentUserId == widget.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message your own listing')),
      );
      Navigator.of(context).pop();
      return;
    }

    await _createChatRoomIfNeeded();
  }

  Future<void> _createChatRoomIfNeeded() async {
    if (currentUserId == null) return;

    final chatRoomId =
        _getChatRoomId(currentUserId!, widget.sellerId, widget.itemId);
    final chatRoomRef =
        FirebaseFirestore.instance.collection('chatRooms').doc(chatRoomId);

    try {
      final chatRoom = await chatRoomRef.get();
      if (!chatRoom.exists) {
        // Create chat room with proper security metadata
        await chatRoomRef.set({
          'participants': [currentUserId, widget.sellerId],
          'itemId': widget.itemId,
          'itemName': widget.itemName,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUserId, // Add creator ID for security rules
          'unreadCount': 0,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating chat: $e')),
      );
    }
  }

  String _getChatRoomId(String userId1, String userId2, String itemId) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}_$itemId';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUserId == null) return;

    setState(() => isLoading = true);
    final message = _messageController.text.trim();

    try {
      // First verify the chat room exists and you're a participant
      final chatRoomId =
          _getChatRoomId(currentUserId!, widget.sellerId, widget.itemId);
      final chatRoomRef =
          FirebaseFirestore.instance.collection('chatRooms').doc(chatRoomId);

      final chatRoom = await chatRoomRef.get();
      if (!chatRoom.exists) {
        // Create chat room if it doesn't exist
        await chatRoomRef.set({
          'participants': [currentUserId, widget.sellerId],
          'itemId': widget.itemId,
          'itemName': widget.itemName,
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUserId,
          'unreadCount': 0,
        });
      }

      // Add the message
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'chatRoomId': chatRoomId,
      });

      // Update chat room's last message
      await chatRoomRef.update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSentBy': currentUserId,
        'unreadCount': FieldValue.increment(1),
      });

      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Rest of the UI code remains the same...
  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Chat')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final chatRoomId =
        _getChatRoomId(currentUserId!, widget.sellerId, widget.itemId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

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

                    return Align(
                      alignment: isMyMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMyMessage ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          message['message'] as String,
                          style: TextStyle(
                            color: isMyMessage ? Colors.white : Colors.black,
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
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
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
    _scrollController.dispose();
    super.dispose();
  }
}
