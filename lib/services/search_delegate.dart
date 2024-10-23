import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_1/services/utils.dart';

class ProductSearchDelegate extends SearchDelegate {
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
    return _buildSearchResults(context, query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context, query);
  }

  Widget _buildSearchResults(BuildContext context, String query) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('items')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;
        final filteredItems = items.where((doc) {
          final item = doc.data() as Map;
          final name = item['name'].toString().toLowerCase();
          final price = item['price'].toString().toLowerCase();
          final searchQuery = query.toLowerCase();

          return name.contains(searchQuery) || price.contains(searchQuery);
        }).toList();

        if (filteredItems.isEmpty) {
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
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index].data() as Map<String, dynamic>;
            final name = item['name'].toString();
            final price = item['price'].toString();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
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
                          child: Image.network(
                            item['images'][0],
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.image_not_supported, size: 30),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: _highlightMatches(
                          name,
                          query,
                          Theme.of(context).primaryColor,
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: _highlightMatches(
                          '₹$price',
                          query,
                          Theme.of(context).primaryColor,
                        ),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => DraggableScrollableSheet(
                      initialChildSize: 0.9,
                      maxChildSize: 1.0,
                      minChildSize: 0.3,
                      builder: (_, scrollController) => ItemDetailsPage(
                        item: item,
                        showFullScreen: false,
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
  }

  List<TextSpan> _highlightMatches(
      String text, String query, Color highlightColor) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final matches = query.toLowerCase().allMatches(text.toLowerCase());
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    List<TextSpan> spans = [];
    int start = 0;

    for (var match in matches) {
      if (match.start != start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          color: highlightColor,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = match.end;
    }

    if (start != text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }
}

// Add this class to manage filters
class FilterOptions {
  String? sortBy;
  bool ascending;
  RangeValues? priceRange;
  DateTime? startDate;
  DateTime? endDate;

  FilterOptions({
    this.sortBy,
    this.ascending = true,
    this.priceRange,
    this.startDate,
    this.endDate,
  });
}

// Modify your HomeScreen class to include these new features
