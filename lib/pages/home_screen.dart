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
  bool _isLoadingStateFilter = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filterService = FilterService();
    _loadAds();
  }

  // Ads related properties
  List<Map<String, dynamic>> _ads = [];

  // Widget _buildFilteredItemsGrid() {
  //   return FutureBuilder<QuerySnapshot>(
  //     // First check if the category has any items
  //     future: _filterService.getFilteredQuery().get(),
  //     builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
  //       // Show loading indicator while checking
  //       if (_isLoading) {
  //         return Center(
  //           child: CircularProgressIndicator(
  //             valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
  //           ),
  //         );
  //       }

  //       // If we have data, stream the results
  //       if (snapshot.hasData) {
  //         return StreamBuilder<QuerySnapshot>(
  //           stream: _filterService.getFilteredQuery().snapshots(),
  //           builder: (context, streamSnapshot) {
  //             if (!streamSnapshot.hasData ||
  //                 streamSnapshot.data!.docs.isEmpty) {
  //               return _buildEmptyState();
  //             }
  //             return _buildGridContent(streamSnapshot.data!.docs);
  //           },
  //         );
  //       }

  //       // If we don't have data yet, show empty state
  //       return _buildEmptyState();
  //     },
  //   );
  // }

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
        // Show loading indicator while data is being fetched
        if (_isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          );
        }

        // Check for errors
        if (snapshot.hasError) {
          return Center(
            child: Text('Something went wrong'),
          );
        }

        // Show loading indicator while waiting for data
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          );
        }

        // If we have data but it's empty, show empty state
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // If we have data, show the grid
        return _buildGridContent(snapshot.data!.docs);
      },
    );
  }

// Updated category update method
  Future<void> _updateCategory(String category) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update category in filter service
      _filterService.selectedCategory = category == 'All' ? null : category;

      // Reset other filters but keep the category
      _filterService.resetAllFiltersExceptCategory();

      // Add a small delay to ensure loading indicator is shown
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('Error updating category: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    final displayCategories = Utils.categories.take(3).toList();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 3) {
            return PopupMenuButton<String>(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
              onSelected: (category) async {
                await _updateCategory(category);
              },
              itemBuilder: (BuildContext context) {
                return Utils.categories.skip(3).map((String category) {
                  return PopupMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList();
              },
            );
          }

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
                MaterialPageRoute(builder: (_) => ItemWizard()),
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
                      _buildFeaturedItemsSection(), //
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
          return Card(
            margin: EdgeInsets.all(8),
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.black54,
                    child: ImageSlider(
                      items: _ads, // Your ads list from Firebase
                      height: 200,
                      autoSlide: true,
                      isAd: true,
                      autoSlideDuration: Duration(seconds: 3),
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

// Add this to HomeScreen for featured items display
  Widget _buildFeaturedItemsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FeaturedService.getFeaturedItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();

        final featuredItems = snapshot.data!.docs;
        if (featuredItems.isEmpty) return SizedBox.shrink();

        return Container(
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Featured Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: featuredItems.length,
                  itemBuilder: (context, index) {
                    final featuredItem =
                        featuredItems[index].data() as Map<String, dynamic>;
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('items')
                          .doc(featuredItem['itemId'])
                          .get(),
                      builder: (context, itemSnapshot) {
                        if (!itemSnapshot.hasData) return SizedBox.shrink();

                        final item =
                            itemSnapshot.data!.data() as Map<String, dynamic>;
                        return Container(
                          width: 200,
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          child: Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(item['images'][0]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text('\$${item['price']}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) async {
    await _filterService.showFilterDialog(context);
    setState(() {});
  }
}
