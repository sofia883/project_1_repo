import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DetailedResultScreen extends StatelessWidget {
  final QueryDocumentSnapshot selectedDoc;
  final List<QueryDocumentSnapshot> allDocs;
  final FirebaseStorage storage = FirebaseStorage.instance;

  DetailedResultScreen({
    Key? key,
    required this.selectedDoc,
    required this.allDocs,
  }) : super(key: key);

  Future<String?> _getImageUrl(String itemId) async {
    try {
      final ref = storage.ref().child('items/$itemId.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = selectedDoc.data() as Map<String, dynamic>;

    // Get related items by category
    final categoryRelatedDocs = allDocs
        .where((doc) {
          final item = doc.data() as Map<String, dynamic>;
          return item['category'] == selectedItem['category'] &&
              doc.id != selectedDoc.id;
        })
        .take(5)
        .toList();

    // Get related items by city
    final cityRelatedDocs = allDocs
        .where((doc) {
          final item = doc.data() as Map<String, dynamic>;
          return item['address']['city'] == selectedItem['address']['city'] &&
              doc.id != selectedDoc.id &&
              !categoryRelatedDocs.contains(doc);
        })
        .take(5)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedItem['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => _openChat(context, selectedDoc.id),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Selected Item
          _buildDetailedItemCard(selectedDoc, true),

          // Category Related Items
          if (categoryRelatedDocs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Similar Items',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...categoryRelatedDocs
                .map((doc) => _buildDetailedItemCard(doc, false)),
          ],

          // Location Related Items
          if (cityRelatedDocs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'More from ${selectedItem['address']['city']}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...cityRelatedDocs.map((doc) => _buildDetailedItemCard(doc, false)),
          ],

          // No More Items Message
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No more items found 😊',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
Widget _buildDetailedItemCard(QueryDocumentSnapshot doc, bool isMainItem) {
  final item = doc.data() as Map<String, dynamic>;
  final images = List<String>.from(item['images'] ?? []);

  return Card(
    margin: EdgeInsets.all(isMainItem ? 16 : 8),
    elevation: isMainItem ? 4 : 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          CachedNetworkImage(
            imageUrl: images[0],
            height: isMainItem ? 300 : 200,
            width: double.infinity,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero, // Remove fade animation
            placeholderFadeInDuration: Duration.zero,
            errorWidget: (context, url, error) => Container(
              height: isMainItem ? 300 : 200,
              color: Colors.grey[300],
              child: const Icon(Icons.image, size: 64),
            ),
          )
        else
          Container(
            height: isMainItem ? 300 : 200,
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 64),
          ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: TextStyle(
                        fontSize: isMainItem ? 24 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          '${item['address']['city']}, ${item['address']['state']}',
                          style: TextStyle(
                            fontSize: isMainItem ? 16 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (isMainItem) ...[
                      const SizedBox(height: 16),
                      Text(
                        item['description'] ?? 'No description available',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }
  void _openChat(BuildContext context, String itemId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(itemId: itemId),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  final String itemId;

  const ChatScreen({Key? key, required this.itemId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const Center(child: Text('Chat interface coming soon')),
    );
  }
}
