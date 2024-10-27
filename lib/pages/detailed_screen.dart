import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_1/services/image_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:project_1/main.dart';
import 'chat_page.dart';

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

class _DetailedResultScreenState extends State<DetailedResultScreen>
    with RouteAware {
  late int currentViewCount;
  List<QueryDocumentSnapshot> relatedItems = [];
  bool isLoading = true;
  StreamSubscription<DocumentSnapshot>? _docSubscription;
  Map<String, bool> expandedItems = {}; // Track expanded state of items

  bool hasIncrementedView = false;

  @override
  void initState() {
    super.initState();
    _fetchRelatedItems();
    _initializeViewCount();
    _setupDocumentListener();
  }

// In DetailedResultScreen class, modify the _initializeViewCount method:
  Future<void> _initializeViewCount() async {
    try {
      final item = widget.selectedDoc.data() as Map<String, dynamic>;
      currentViewCount = item['viewCount'] ?? 0;

      if (!hasIncrementedView) {
        // Create a batch to ensure atomic update
        WriteBatch batch = FirebaseFirestore.instance.batch();

        DocumentReference docRef = FirebaseFirestore.instance
            .collection('items')
            .doc(widget.selectedDoc.id);

        batch.update(docRef, {
          'viewCount': FieldValue.increment(1),
          'lastViewed': FieldValue.serverTimestamp(),
        });

        await batch.commit();
        hasIncrementedView = true;
      }
    } catch (e) {
      print('Error updating view count: $e');
      // Don't show error to user as view count is not critical
    }
  }

  void _setupDocumentListener() {
    _docSubscription = FirebaseFirestore.instance
        .collection('items')
        .doc(widget.selectedDoc.id)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        setState(() {
          currentViewCount = snapshot.data()?['viewCount'] ?? 0;
        });
      }
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // When returning to this screen, only refresh the count without incrementing
    FirebaseFirestore.instance
        .collection('items')
        .doc(widget.selectedDoc.id)
        .get()
        .then((doc) {
      if (mounted && doc.exists) {
        setState(() {
          currentViewCount = doc.data()?['viewCount'] ?? 0;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _docSubscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _fetchRelatedItems() async {
    setState(() => isLoading = true);

    try {
      final item = widget.selectedDoc.data() as Map<String, dynamic>;
      final category = item['category'] ?? '';
      final itemName = item['name'] ?? '';
      final city = item['address']?['city'] ?? '';
      final state = item['address']?['state'] ?? '';

      // Get all potential related items
      final QuerySnapshot allRelatedItems = await FirebaseFirestore.instance
          .collection('items')
          .where(FieldPath.documentId, isNotEqualTo: widget.selectedDoc.id)
          .get();

      // Sort items based on match criteria
      List<QueryDocumentSnapshot> categoryAndNameMatches = [];
      List<QueryDocumentSnapshot> categoryMatches = [];
      List<QueryDocumentSnapshot> addressMatches = [];

      for (var doc in allRelatedItems.docs) {
        final relatedItem = doc.data() as Map<String, dynamic>;
        bool categoryMatch = relatedItem['category'] == category;
        bool nameMatch = relatedItem['name']
                .toString()
                .toLowerCase()
                .contains(itemName.toLowerCase()) ||
            itemName
                .toLowerCase()
                .contains(relatedItem['name'].toString().toLowerCase());
        bool addressMatch = relatedItem['address']?['city'] == city &&
            relatedItem['address']?['state'] == state;

        if (categoryMatch && nameMatch) {
          categoryAndNameMatches.add(doc);
        } else if (categoryMatch) {
          categoryMatches.add(doc);
        } else if (addressMatch) {
          addressMatches.add(doc);
        }
      }

      // Combine all matches in priority order
      setState(() {
        relatedItems = [
          ...categoryAndNameMatches,
          ...categoryMatches,
          ...addressMatches,
        ];
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching related items: $e');
      setState(() => isLoading = false);
    }
  }

  void _showItemDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] ?? 'Item Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Brand: ${item['brand'] ?? 'N/A'}'),
              Text('Warranty: ${item['warranty'] ?? 'N/A'}'),
              Text('Description: ${item['description'] ?? 'N/A'}'),
              Text('Price: \$${item['price']?.toString() ?? 'N/A'}'),
              Text(
                  'Location: ${item['address']?['city']}, ${item['address']?['state']}'),
              // Add more details as needed
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
  // ... keep existing initState, dispose, and other methods ...

  Widget _buildItemCard(QueryDocumentSnapshot doc, bool isMainItem) {
    final item = doc.data() as Map<String, dynamic>;
    final images = List<String>.from(item['images'] ?? []);
    final viewCount = isMainItem ? currentViewCount : (item['viewCount'] ?? 0);
    final isExpanded = expandedItems[doc.id] ?? false;

    return Card(
      margin: EdgeInsets.all(isMainItem ? 16 : 8),
      elevation: isMainItem ? 4 : 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImageSlider(
            isMainItem: true,
            items: images,
            height: isMainItem ? 300 : 150,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] ?? 'Unnamed Item',
                        style: TextStyle(
                          fontSize: isMainItem ? 24 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('$viewCount'),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.chat_bubble_outline),
                          onPressed: () => _openChat(doc),
                          tooltip: 'Chat about this item',
                        ),
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() {
                              expandedItems[doc.id] = !isExpanded;
                            });
                          },
                          tooltip: 'Show more details',
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '\$${item['price']?.toString() ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: isMainItem ? 20 : 16,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item['address']?['city']}, ${item['address']?['state']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  SizedBox(height: 16),
                  Divider(),
                  _buildDetailRow('Brand', item['brand']),
                  _buildDetailRow('Category', item['category']),
                  _buildDetailRow('Warranty', item['warranty']),
                  _buildDetailRow('Condition', item['condition']),
                  _buildDetailRow('Description', item['description']),
                  if (item['specifications'] != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Specifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    ...List<Widget>.from(
                      (item['specifications'] as Map<String, dynamic>)
                          .entries
                          .map((e) => _buildDetailRow(e.key, e.value)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(QueryDocumentSnapshot doc) {
    final item = doc.data() as Map<String, dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to chat')),
      );
      return;
    }

    if (item['userId'] == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This is your own item')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          itemId: doc.id,
          sellerId: item['userId'],
          itemName: item['name'] ?? 'Unnamed Item',
          // itemImage: (item['images'] as List<dynamic>).isNotEmpty
          //     ? item['images'][0]
          //     : '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildItemCard(widget.selectedDoc, true),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Relatehhd Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (relatedItems.isEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('No related items found'),
              )
            else
              // In DetailedResultScreen class, modify the GridView.builder in the build method:

              GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: relatedItems.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () {
                    // Navigate to a new DetailedResultScreen for the selected related item
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedResultScreen(
                          selectedDoc: relatedItems[index],
                          allDocs: widget.allDocs,
                        ),
                      ),
                    );
                  },
                  child: _buildItemCard(relatedItems[index], false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
