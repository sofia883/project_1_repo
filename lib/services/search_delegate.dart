import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_1/pages/detailed_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductSearchDelegate extends SearchDelegate {
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final popularProductsStream = FirebaseFirestore.instance
      .collection('items')
      .orderBy('viewCount', descending: true)
      .limit(10)
      .snapshots();

  static const String searchHistoryKey = 'search_history';

  Future<List<String>> _getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(searchHistoryKey) ?? [];
    return history.reversed.toList();
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(searchHistoryKey) ?? [];

    history.remove(query);
    history.add(query);

    if (history.length > 10) {
      history.removeAt(0);
    }

    await prefs.setStringList(searchHistoryKey, history);
  }

  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(searchHistoryKey) ?? [];
    history.remove(query);
    await prefs.setStringList(searchHistoryKey, history);
  }

  Future<void> _clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(searchHistoryKey);
  }

  Widget _buildSearchHistorySection(
      BuildContext context, List<String> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Clear All'),
                onPressed: () async {
                  await _clearAllHistory();
                  (context as Element).markNeedsBuild();
                },
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final historyItem = history[index];
            return Dismissible(
              key: Key(historyItem),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) async {
                await _removeFromHistory(historyItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "$historyItem" from history'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        await _addToHistory(historyItem);
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                );
              },
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(historyItem),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () async {
                    await _removeFromHistory(historyItem);
                    (context as Element).markNeedsBuild();
                  },
                ),
                onTap: () {
                  query = historyItem;
                  showResults(context);
                },
              ),
            );
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPopularProducts() {
    return StreamBuilder<QuerySnapshot>(
      stream: popularProductsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;
        if (items.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Popular Searches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final doc = items[index];
                  final item = doc.data() as Map<String, dynamic>;
                  final images = List<String>.from(item['images'] ?? []);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailedResultScreen(
                            selectedDoc: doc,
                            allDocs: items,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: images[0],
                                height: 120,
                                width: 150,
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                              ),
                            )
                          else
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '\$${item['price']}',
                                  style: const TextStyle(color: Colors.orange),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return SingleChildScrollView(
        child: FutureBuilder<List<String>>(
          future: _getSearchHistory(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildPopularProducts();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.data!.isNotEmpty)
                  _buildSearchHistorySection(context, snapshot.data!),
                _buildPopularProducts(),
              ],
            );
          },
        ),
      );
    }

    return _buildSearchResults(context, query);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isNotEmpty) {
      _addToHistory(query);
    }
    return _buildSearchResults(context, query);
  }

  Widget _buildSearchResults(BuildContext context, String query) {
    return StreamBuilder(
      stream: firestore.collection('items').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Network connection issue\nPlease check your internet connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Force rebuild to retry
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox(); // No loading indicator
        }

        final items = snapshot.data!.docs;
        final filteredItems = items.where((doc) {
          final item = doc.data() as Map;
          final name = item['name'].toString().toLowerCase();
          final searchQuery = query.toLowerCase();

          final address = item['address'] as Map?;
          final city = address?['city']?.toString().toLowerCase() ?? '';
          final state = address?['state']?.toString().toLowerCase() ?? '';

          return name.contains(searchQuery) ||
              city.contains(searchQuery) ||
              state.contains(searchQuery);
        }).toList();

        if (filteredItems.isEmpty) {
          return _buildNoResultsFound(query);
        }

        return ListView(
          children: [
            ...filteredItems.map(
              (doc) => _buildSearchResultCard(context, doc, query, items),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoResultsFound(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No results found for "$query"',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const Text('😔', style: TextStyle(fontSize: 32)),
        ],
      ),
    );
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final List<TextSpan> spans = [];
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: const TextStyle(color: Colors.black),
        ));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(color: Colors.black),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      ));

      start = index + query.length;
    }

    return RichText(text: TextSpan(children: spans));
  }

  Future<String?> _getImageUrl(String itemId) async {
    try {
      final ref = storage.ref().child('items/$itemId.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL: $e');
      return null;
    }
  }

  Widget _buildSearchResultCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
    String query,
    List<QueryDocumentSnapshot> allItems,
  ) {
    final item = doc.data() as Map<String, dynamic>;
    final itemId = doc.id;

    return FutureBuilder<String?>(
      future: _getImageUrl(itemId),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            // Add this import at the top
// Then replace the current leading part in the ListTile with this:
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: item['images']?.isNotEmpty ?? false
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item['images'][0],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                      ),
                    )
                  : const Icon(Icons.image_not_supported, size: 30),
            ),
            title: _highlightText(item['name'], query),
            subtitle: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue),
                SizedBox(width: 4),
                Expanded(
                  child: _highlightText(
                    '${item['address']['city']}, ${item['address']['state']}',
                    query,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailedResultScreen(
                    selectedDoc: doc,
                    allDocs: allItems,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
