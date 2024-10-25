import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_1/pages/detailed_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_1/services/utils.dart';

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
    return prefs.getStringList(searchHistoryKey)?.reversed.toList() ?? [];
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(searchHistoryKey) ?? [];

    // Remove duplicate if exists
    history.remove(query.trim());
    // Add new query at the end
    history.add(query.trim());

    // Keep only last 10 searches
    if (history.length > 10) {
      history = history.sublist(history.length - 10);
    }

    await prefs.setStringList(searchHistoryKey, history);
  }

  Widget _buildSearchResultCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
    String query,
    List<QueryDocumentSnapshot> allItems,
  ) {
    final item = doc.data() as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
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
                    fadeInDuration: Duration.zero,
                    placeholderFadeInDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
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
            const Icon(Icons.location_on, size: 16, color: Colors.blue),
            const SizedBox(width: 4),
            Expanded(
              child: _highlightText(
                '${item['address']['city']}, ${item['address']['state']}',
                query,
              ),
            ),
          ],
        ),
        onTap: () async {
          // Store search query when item is selected
          if (query.isNotEmpty) {
            await _addToHistory(query);
          }
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
  }

  @override
  Widget buildResults(BuildContext context) {
    // Remove storing history here since we'll store it when item is selected
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
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox();
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
          children: filteredItems
              .map(
                (doc) => _buildSearchResultCard(context, doc, query, items),
              )
              .toList(),
        );
      },
    );
  }

  // Also add history storage to popular products selection
  Widget _buildPopunlarProducts() {
    return StreamBuilder<QuerySnapshot>(
      stream: popularProductsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final items = snapshot.data!.docs;
        if (items.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
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
                    onTap: () async {
                      // Store product name as search history when selected from popular
                      if (item['name'] != null) {
                        await _addToHistory(item['name']);
                      }
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
                                placeholderFadeInDuration: Duration.zero,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                ),
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

  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(searchHistoryKey) ?? [];
    history.remove(query);
    await prefs.setStringList(searchHistoryKey, history);
  }

  Widget _buildSearchHistorySection(
      BuildContext context, List<String> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        // If history becomes empty during StatefulBuilder lifetime, return empty widget
        if (history.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Searches',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _clearAllHistory();
                      setState(() {
                        history.clear();
                      });
                      query = '';
                      showSuggestions(context);
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: history.map((historyItem) {
                return Dismissible(
                  key: Key(historyItem),
                  background: Container(
                    color: Colors.red.shade100,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) async {
                    setState(() {
                      history.remove(historyItem);
                    });
                    await _removeFromHistory(historyItem);

                    // Force rebuild if this was the last item
                    if (history.isEmpty) {
                      query = '';
                      showSuggestions(context);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed "$historyItem"'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                            await _addToHistory(historyItem);
                            setState(() {
                              history.add(historyItem);
                            });
                          },
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              query = historyItem;
                              showResults(context);
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    historyItem,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.grey),
                          onPressed: () async {
                            setState(() {
                              history.remove(historyItem);
                            });
                            await _removeFromHistory(historyItem);

                            // Force rebuild if this was the last item
                            if (history.isEmpty) {
                              query = '';
                              showSuggestions(context);
                            }

                            
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(searchHistoryKey);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return SingleChildScrollView(
        child: FutureBuilder<List<String>>(
          future: _getSearchHistory(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return PopularItemsWidget();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.data!.isNotEmpty)
                  _buildSearchHistorySection(context, snapshot.data!),
                PopularItemsWidget()
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
}
