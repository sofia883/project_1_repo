// DetailedResultScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class DetailedResultScreen extends StatefulWidget {
  final QueryDocumentSnapshot selectedDoc;
  final List<QueryDocumentSnapshot>? allDocs;

  DetailedResultScreen({
    Key? key,
    required this.selectedDoc,
    this.allDocs,
  }) : super(key: key);

  @override
  State<DetailedResultScreen> createState() => _DetailedResultScreenState();
}

class _DetailedResultScreenState extends State<DetailedResultScreen> {
  late int currentViewCount;

  late StreamSubscription<DocumentSnapshot> _viewCountSubscription;
  List<QueryDocumentSnapshot> relatedItems = [];
  bool isLoading = true;
  bool _hasIncrementedView = false;

  @override
  void initState() {
    super.initState();
    _fetchRelatedItems();
    final item = widget.selectedDoc.data() as Map<String, dynamic>;
    currentViewCount =
        (item['viewCount'] ?? 0) + 1; // Increment immediately for UI
    _incrementViewCount();
  }

  Future<void> _fetchRelatedItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      final item = widget.selectedDoc.data() as Map<String, dynamic>;

      final category = item['category'] ?? '';
      final city = item['address']?['city'] ?? '';
      final state = item['address']?['state'] ?? '';

      final relatedItemsQuery = await FirebaseFirestore.instance
          .collection('items')
          .where('category', isEqualTo: category)
          .where('address.city', isEqualTo: city)
          .where('address.state', isEqualTo: state)
          .where(FieldPath.documentId, isNotEqualTo: widget.selectedDoc.id)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          relatedItems = relatedItemsQuery.docs;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching related items: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.selectedDoc.id)
          .update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing view count: $e');
    }
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
            SizedBox(
              height: isMainItem ? 300 : 150,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: images[0],
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unnamed Item',
                  style: TextStyle(
                    fontSize: isMainItem ? 24 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${item['address']['city']}, ${item['address']['state']}',
                              style: TextStyle(
                                fontSize: isMainItem ? 16 : 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          isMainItem
                              ? '$currentViewCount'
                              : '${item['viewCount'] ?? 0}',
                          style: TextStyle(
                            fontSize: isMainItem ? 16 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.message),
            onPressed: () => _openChat(context, widget.selectedDoc.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDetailedItemCard(widget.selectedDoc, true),
            _buildRelatedItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedItems() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (relatedItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('No related items found'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Related Items',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: relatedItems.length,
            itemBuilder: (context, index) {
              final doc = relatedItems[index];
              return GestureDetector(
                onTap: () => _navigateToItem(doc),
                child: _buildDetailedItemCard(doc, false),
              );
            },
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  void _navigateToItem(QueryDocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailedResultScreen(
          selectedDoc: doc,
        ),
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
