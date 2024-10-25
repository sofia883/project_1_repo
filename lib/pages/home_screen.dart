import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_item_screen.dart';
import 'package:project_1/services/search_delegate.dart';
import 'package:project_1/services/utils.dart';
import 'profile_page.dart';
import 'add_ads_screen.dart';
import 'detailed_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FilterService _filterService;
  bool _isLoadingStateFilter = true;
  bool _isLoading = true;

  // Categories to show in the main row
  final List<String> _mainCategories = [
    'All',
    'Electronics',
    'Fashion',
    'Home',
  ];

  // All categories for the dropdown
  final List<String> _allCategories = [
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
    _loadAds();
  }

  // Ads related properties
  List<Map<String, dynamic>> _ads = [];

  Future<void> _loadAds() async {
    try {
      final adsSnapshot = await FirebaseFirestore.instance
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _ads = adsSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print('Error loading ads: $e');
    }
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
              onPressed: () => _showFilterDialog(context),
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
                MaterialPageRoute(builder: (_) => AddItemScreen()),
              ).then((_) => setState(() {})),
            ),
          ],
        ),
        backgroundColor: Colors.grey[100],
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _isLoading = true;
            });
            await _loadAds();
            setState(() {
              _isLoading = false;
            });
          },
          child: CustomScrollView(
              physics:
                  AlwaysScrollableScrollPhysics(), // This ensures pull-to-refresh works even when content doesn't fill the screen
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildCategoryBar(),
                      if (_ads.isNotEmpty) _buildAdsCarousel(),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildFilteredItemsGrid(),
                  ),
                )
              ]),
        ));
  }

  Widget _buildAdsCarousel() {
    return Container(
      height: 200,
      child: PageView.builder(
        itemCount: _ads.length,
        itemBuilder: (context, index) {
          final ad = _ads[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: Stack(
              children: [
                Image.network(
                  ad['imageUrl'] ?? 'https://via.placeholder.com/400x200',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ad['title'] ?? 'Advertisement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ad['description'] ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredItemsGrid() {
    return FutureBuilder(
      future: Future.delayed(
          Duration(milliseconds: 500)), // Reduced delay for better UX
      builder: (context, snapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _filterService.getFilteredQuery().snapshots(),
          builder: (context, itemSnapshot) {
            // Handle error state
            if (itemSnapshot.hasError) {
              return _filterService.buildEmptyState();
            }

            // During refresh, show loading indicator overlay while keeping previous content visible
            if (_isLoading &&
                itemSnapshot.connectionState == ConnectionState.waiting) {
              return Stack(
                children: [
                  // Show previous content (if any)
                  if (itemSnapshot.hasData &&
                      itemSnapshot.data!.docs.isNotEmpty)
                    _buildGridContent(itemSnapshot.data!.docs),

                  // Show loading overlay
                  Container(
                    color: Colors.white.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Refreshing...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Initial loading state (when no previous data exists)
            if (!itemSnapshot.hasData && _isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading items...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    )
                  ],
                ),
              );
            }

            // Handle case where data is null or empty
            final data = itemSnapshot.data;
            if (data == null || data.docs.isEmpty) {
              return _filterService.buildEmptyState();
            }

            // Update loading state flag
            if (_isLoadingStateFilter == false) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _isLoadingStateFilter = true;
                });
              });
            }

            // Build grid with the data
            return _buildGridContent(data.docs);
          },
        );
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
            // Fixed navigation to DetailedResultScreen
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
    // Show first 3 categories only
    final displayCategories = _allCategories.take(3).toList();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4, // Show 4 items total (3 categories + See More)
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          // If it's the last item (index 3), show the See More button
          if (index == 3) {
            return PopupMenuButton<String>(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.blue), // Change border to blue
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See More',
                      style: TextStyle(
                        color: Colors.blue, // Change text color to blue
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.blue, // Change icon color to blue
                      size: 20,
                    ),
                  ],
                ),
              ),
              onSelected: _updateCategory,
              itemBuilder: (BuildContext context) {
                return _allCategories
                    .skip(
                        3) // Skip the first 3 categories that are already shown
                    .map((String category) {
                  return PopupMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList();
              },
            );
          }

          // For the first 3 items, show categories
          String category = displayCategories[index];
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
