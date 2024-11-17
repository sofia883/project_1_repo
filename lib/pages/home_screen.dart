import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_item_screen.dart';
import 'package:project_1/services/search_delegate.dart';
import 'package:project_1/services/utils.dart';
import 'profile_page.dart';
import 'add_ads_screen.dart';
import 'detailed_screen.dart';
import 'all_conversations.dart';
import 'package:project_1/services/image_slider.dart';
import 'package:project_1/services/featured_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late FilterService _filterService;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filterService = FilterService();
    // Initialize with "All" category
    _updateCategory('All');
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _filterService.selectedCategory != null
                ? 'No items found in ${_filterService.selectedCategory} category'
                : 'No items found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredItemsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _filterService.getFilteredQuery().snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        // Show loading indicator only when explicitly loading
        if (_isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          );
        }

        // Check if there was an error
        if (snapshot.hasError) {
          return Center(
            child: Text('Something went wrong'),
          );
        }

        // Show loading indicator only during initial data fetch
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          );
        }

        // If no data available, show an empty state
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Display the grid of items once data is available
        return _buildGridContent(snapshot.data!.docs);
      },
    );
  }

  Widget _buildGridContent(List<QueryDocumentSnapshot> items) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final doc = items[index];
        final item = doc.data() as Map<String, dynamic>;
        final images = List<String>.from(item['images'] ?? []);
        final timestamp = item['createdAt'] as Timestamp?;
        final formattedDate = timestamp != null
            ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
            : 'No date';

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DetailedResultScreen(
                  selectedDoc: doc,
                  allDocs: items,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10)),
                      image: DecorationImage(
                        image: NetworkImage(images.isNotEmpty
                            ? images[0]
                            : 'https://via.placeholder.com/150'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'No Title',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      IconButton(
                          onPressed: () => _deleteItem(doc.id),
                          icon: Icon(Icons.delete)),
                      Text(
                        "\$${item['price']?.toString() ?? 'N/A'}",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    // Take the first 3 categories
    final displayCategories = Utils.categories.take(3).toList();

    // If selectedCategory is not 'All' and is not in the first 3 categories, insert it at second position
    String currentCategory = _filterService.selectedCategory ?? 'All';

    if (currentCategory != 'All' &&
        !displayCategories.any((cat) => cat.name == currentCategory)) {
      // Insert the selected category in the second position
      displayCategories.insert(
          1, Utils.categories.firstWhere((cat) => cat.name == currentCategory));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4, // 3 categories + "See More"
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // "See More" Button
          if (index == 3) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CategorySelectionScreen(
                      onCategorySelected: _updateCategory,
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'See More',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.blue, size: 20),
                  ],
                ),
              ),
            );
          }

          // Display categories
          final category = displayCategories[index];
          final isSelected = currentCategory == category.name;

          return GestureDetector(
            onTap: () => _updateCategory(category.name),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected && category.name != 'All')
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        category.icon,
                        color: isSelected ? Colors.white : Colors.orange,
                        size: 16,
                      ),
                    ),
                  Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.orange,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateCategory(String category) async {
    if (category == _filterService.selectedCategory)
      return; // Don't update if same category

    setState(() {
      _isLoading = true;
    });

    try {
      _filterService.selectedCategory = category == 'All' ? null : category;
      _filterService.resetAllFiltersExceptCategory();
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('Error updating category: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to delete items')),
      );
      return;
    }

    try {
      await _firestore.collection('items').doc(itemId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Marketplace'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(context: context, delegate: ProductSearchDelegate());
            },
          ),
          IconButton(
            icon: Icon(Icons.add_business, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddAdvertisementScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.black),
            onPressed: () => _filterService.showFilterDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.person, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ItemWizard()),
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryBar(),
            Expanded(child: _buildFilteredItemsGrid()),
          ],
        ),
      ),
    );
  }
}
