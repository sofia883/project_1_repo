import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ItemDetailsPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showFullScreen;

  const ItemDetailsPage({
    Key? key,
    required this.item,
    this.showFullScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent(context);

    if (showFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(item['name'] ?? 'Item Details'),
        ),
        body: content,
      );
    }

    // For bottom sheet mode
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      children: [
        // Image Carousel
        if (item['images'] != null && (item['images'] as List).isNotEmpty)
          Container(
            height: 200,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: (item['images'] as List).length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      item['images'][index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: Icon(Icons.error)),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: CircularProgressIndicator());
                      },
                    );
                  },
                ),
                // Optional: Add image counter indicator here
              ],
            ),
          ),

        SizedBox(height: 16),

        // Title
        Text(
          item['name'] ?? 'Untitled Item',
          style: Theme.of(context).textTheme.headlineMedium,
        ),

        SizedBox(height: 8),

        // Price
        Text(
          '₹${item['price']?.toString() ?? 'Price not available'}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),

        SizedBox(height: 16),

        // Description Section
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: 8),
        Text(
          item['description'] ?? 'No description available',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        SizedBox(height: 16),

        // Contact Information
        Card(
          child: Column(
            children: [
              ListTile(
                leading:
                    Icon(Icons.phone, color: Theme.of(context).primaryColor),
                title: Text('Contact'),
                subtitle: Text(item['phone'] ?? 'No phone number available'),
                onTap: () {
                  // TODO: Implement phone call functionality
                  // You can use url_launcher package to make phone calls
                },
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.location_on,
                    color: Theme.of(context).primaryColor),
                title: Text('Location'),
                subtitle: Text(item['address'] ?? 'No address available'),
                onTap: () {
                  // TODO: Implement map navigation
                  // You can use url_launcher package to open maps
                },
              ),
            ],
          ),
        ),

        // Posted Date
        if (item['createdAt'] != null) ...[
          SizedBox(height: 16),
          Text(
            'Posted on: ${_formatDate(item['createdAt'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],

        SizedBox(height: 16),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    // Handle Timestamp or other date formats as needed
    return date.toString();
  }
}

class FilterService {
  final _loadingController = StreamController<bool>.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  FilterService({
    this.priceRange = const RangeValues(0, 1000),
    this.isPriceFilterActive = false,
    this.selectedCategory,
  });
  RangeValues priceRange;
  bool isPriceFilterActive;
  String? selectedCategory;
  String? selectedCity;
  String? selectedCountry;
  String? selectedTimeFrame;
  bool isLoading = false;

  static const Map<String, Duration> timeFrames = {
    'Last 24 Hours': Duration(hours: 24),
    'This Week': Duration(days: 7),
    'This Month': Duration(days: 30),
    'Last 6 Months': Duration(days: 180),
    'Last Year': Duration(days: 365),
    'Older': Duration(days: 365), // Special case for older items
  };
  void dispose() {
    _loadingController.close();
  }

  void reset() {
    priceRange = const RangeValues(0, 1000);
    isPriceFilterActive = false;
  }

  Future<QuerySnapshot> fetchFilteredResults() async {
    Query query = getFilteredQuery();
    return await query.limit(20).get();
  }

  Query getFilteredQuery() {
    Query query = FirebaseFirestore.instance.collection('items');

    // Apply category filter
    if (selectedCategory != null && selectedCategory != 'All') {
      query = query.where('category', isEqualTo: selectedCategory);
    }

    // Apply price filter
    if (isPriceFilterActive) {
      query = query
          .where('price', isGreaterThanOrEqualTo: priceRange.start)
          .where('price', isLessThanOrEqualTo: priceRange.end);
    }

    // Apply location filters
    if (selectedCity != null) {
      query = query.where('address.city', isEqualTo: selectedCity);
    }
    if (selectedCountry != null) {
      query = query.where('address.country', isEqualTo: selectedCountry);
    }

    // Apply time filter
    if (selectedTimeFrame != null) {
      DateTime cutoffDate;
      if (selectedTimeFrame == 'Older') {
        cutoffDate = DateTime.now().subtract(Duration(days: 365));
        query = query.where('createdAt', isLessThan: cutoffDate);
      } else {
        cutoffDate = DateTime.now().subtract(timeFrames[selectedTimeFrame]!);
        query = query.where('createdAt', isGreaterThan: cutoffDate);
      }
    }

    return query;
  }

  Future<void> showFilterDialog(BuildContext context) async {
    RangeValues tempPriceRange = priceRange;
    bool tempIsPriceFilterActive = isPriceFilterActive;
    String? tempCity = selectedCity;
    String? tempCountry = selectedCountry;
    String? tempTimeFrame = selectedTimeFrame;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price Range',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    RangeSlider(
                      values: tempPriceRange,
                      min: 0,
                      max: 1000,
                      divisions: 20,
                      labels: RangeLabels(
                        '\$${tempPriceRange.start.toStringAsFixed(0)}',
                        '\$${tempPriceRange.end.toStringAsFixed(0)}',
                      ),
                      onChanged: (values) => setState(() {
                        tempPriceRange = values;
                        tempIsPriceFilterActive = true;
                      }),
                    ),
                    SizedBox(height: 16),
                    Text('Location',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(
                          () => tempCity = value.isEmpty ? null : value),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(
                          () => tempCountry = value.isEmpty ? null : value),
                    ),
                    SizedBox(height: 16),
                    Text('Time Frame',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: tempTimeFrame,
                      isExpanded: true,
                      hint: Text('Select Time Frame'),
                      items: [
                        DropdownMenuItem(value: null, child: Text('All Time')),
                        ...timeFrames.keys.map((String time) {
                          return DropdownMenuItem(
                              value: time, child: Text(time));
                        }).toList(),
                      ],
                      onChanged: (value) =>
                          setState(() => tempTimeFrame = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Reset'),
                  onPressed: () {
                    setState(() {
                      tempPriceRange = const RangeValues(0, 1000);
                      tempIsPriceFilterActive = false;
                      tempCity = null;
                      tempCountry = null;
                      tempTimeFrame = null;
                    });
                  },
                ),
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: Text('Apply'),
                  onPressed: () async {
                    // Apply filters immediately
                    priceRange = tempPriceRange;
                    isPriceFilterActive = tempIsPriceFilterActive;
                    selectedCity = tempCity;
                    selectedCountry = tempCountry;
                    selectedTimeFrame = tempTimeFrame;

                    // Close dialog
                    Navigator.pop(context);

                    // Start loading indicator
                    _loadingController.add(true);

                    // Wait for 2 seconds
                    await Future.delayed(Duration(seconds: 2));

                    // Stop loading indicator
                    _loadingController.add(false);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildContentState(
      BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
    // Check the loading state first
    if (isLoading) {
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

    if (snapshot.hasError) {
      return Center(
        child: Text(
          'Error loading items. Please try again.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return buildEmptyState();
    }

    return ListView.builder(
      itemCount: snapshot.data!.docs.length,
      itemBuilder: (context, index) {
        // Your existing item builder code
      },
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty_screen.jpg',
            height: 200,
            width: 200,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 16),
          Text(
            _getEmptyStateMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void resetAllFilters() {
    priceRange = const RangeValues(0, 1000);
    isPriceFilterActive = false;
    selectedCity = null;
    selectedCountry = null;
    selectedTimeFrame = null;
    _loadingController.add(false);
  }

  String _getEmptyStateMessage() {
    if (selectedCategory != null && selectedCategory != 'All') {
      if (isPriceFilterActive) {
        return 'No $selectedCategory items found in price range \$${priceRange.start.toStringAsFixed(0)} - \$${priceRange.end.toStringAsFixed(0)}';
      }
      return 'No $selectedCategory items found';
    }
    if (isPriceFilterActive) {
      return 'No items found in price range \$${priceRange.start.toStringAsFixed(0)} - \$${priceRange.end.toStringAsFixed(0)}';
    }
    return 'No items found';
  }
}
