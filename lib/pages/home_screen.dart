import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_item_screen.dart';
import 'package:project_1/services/search_delegate.dart';
import 'package:project_1/services/utils.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FilterOptions _filterOptions = FilterOptions();
  late FilterService _filterService;
  bool _isLoadingStateFilter = true;

  bool _isLoading =
      true; // Add this at the beginning of your widget state class

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
              icon: Icon(Icons.person, color: Colors.black),
              onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen()),
                  )),
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
    return FutureBuilder(
      future:
          Future.delayed(Duration(seconds: 2)), // Simulate delay for 2 seconds
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          // Show loading indicator once during the initial delay
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                SizedBox(height: 16),
                Text(
                  '${_isLoadingStateFilter ? 'Filtering' : 'Loading'} ${_filterService.selectedCategory ?? 'All'} items...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                )
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _filterService.getFilteredQuery().snapshots(),
          builder: (context, itemSnapshot) {
            if (itemSnapshot.hasError) {
              return _filterService.buildEmptyState();
            }

            if (!itemSnapshot.hasData) {
              // Only show the loading indicator if data is not ready and the state is still loading
              if (_isLoading) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                );
              }
            }

            // Once data is loaded, stop the loading state
            if (_isLoadingStateFilter == false) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _isLoadingStateFilter = true;
              });
            }

            if (itemSnapshot.data!.docs.isEmpty) {
              return _filterService.buildEmptyState();
            }

            final items = itemSnapshot.data!.docs;

            // Build the grid of items
            return GridView.builder(
              padding: EdgeInsets.symmetric(vertical: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              // In _HomeScreenState class, update the _buildFilteredItemsGrid() method
// Replace the item builder section with this updated code:

              itemBuilder: (context, index) {
                final item = items[index].data() as Map<String, dynamic>;
                final images = List<String>.from(item['images'] ?? []);
                final timestamp = item['createdAt'] as Timestamp?;
                final formattedDate = timestamp != null
                    ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                    : 'No date';

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
                              item['name'] ??
                                  'No Title', // Changed from 'title' to 'name'
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
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateCategory(String category) async {
    setState(() {
      _isLoading = true; // Set loading state to true when user taps a category
    });

    // Update the category
    _filterService.selectedCategory = category == 'All' ? null : category;
    _filterService.resetAllFilters();

    // Simulate a small delay or do any async filtering tasks

    // Artificial delay of 1 second
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
            onTap: () {
              setState(() {
                _isLoadingStateFilter =
                    false; // Set loading state to false when user taps
              });

              _updateCategory(category);
            },
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
