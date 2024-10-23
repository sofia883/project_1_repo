import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_item_screen.dart';
import 'package:project_1/services/search_delegate.dart';
import 'package:project_1/services/utils.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FilterOptions _filterOptions = FilterOptions();
  late FilterService _filterService;

  final List<String> _categories = [
    'All',
    'Electronics',
    'Fashion',
    'Home',
    'Furniture',
    'Books',
    'Toys',
    'Sports',
    'Beauty',
    'Health',
    'Automotive',
    'Jewelry',
    'Groceries',
    'Music',
    'Pet Supplies',
    'Garden',
    'Office Supplies',
    'Baby Products'
  ];

  @override
  void initState() {
    super.initState();
    _filterService = FilterService();
  }

  @override
  void dispose() {
    _filterService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Marketplace'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.black),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddItemScreen()),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildCategoryBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildFilteredItemsGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredItemsGrid() {
    return StreamBuilder<bool>(
      stream: _filterService.loadingStream,
      initialData: false,
      builder: (context, loadingSnapshot) {
        // Show loading indicator if filter is being applied
        if (loadingSnapshot.data == true) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(height: 16),
                Text(
                  'Filtering items...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Show filtered items or empty state after loading is done
        return FutureBuilder<void>(
          future: Future.delayed(Duration(seconds: 2)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Still waiting, show loading
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              );
            }

            // Check for query results after delay
            return StreamBuilder<QuerySnapshot>(
              stream: _filterService.getFilteredQuery().snapshots(),
              builder: (context, itemSnapshot) {
                if (itemSnapshot.hasError) {
                  return _filterService.buildEmptyState();
                }

                if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                  return _filterService.buildEmptyState();
                }

                final items = itemSnapshot.data!.docs;
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
                    final item = items[index].data() as Map<String, dynamic>;
                    final images = List<String>.from(item['images'] ?? []);

                    return Container(
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
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(10)),
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
                                  item['title'] ?? 'No Title',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "\$${item['price']?.toString() ?? 'N/A'}",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateCategory(String category) {
    setState(() {
      _filterService.selectedCategory = category == 'All' ? null : category;
      _filterService.reset();
    });
  }

  Widget _buildCategoryBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          String category = _categories[index];
          bool isSelected = _filterService.selectedCategory == category ||
              (category == 'All' && _filterService.selectedCategory == null);

          return GestureDetector(
            onTap: () => _updateCategory(category),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.orange,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterDialog(BuildContext context) async {
    await _filterService.showFilterDialog(context);
    setState(() {});
  }
}
