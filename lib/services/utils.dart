import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:csc_picker/csc_picker.dart';
import 'package:geolocator/geolocator.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

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
  String? selectedState;
  String? selectedCountry;
  String? selectedTimeFrame;
  bool isLoading = false;

  static const Map<String, Duration> timeFrames = {
    'Last 24 Hours': Duration(hours: 24),
    'This Week': Duration(days: 7),
    'This Month': Duration(days: 30),
    'Last 6 Months': Duration(days: 180),
    'Last Year': Duration(days: 365),
    'Older': Duration(days: 365),
  };

  void dispose() {
    _loadingController.close();
  }

  void reset() {
    priceRange = const RangeValues(0, 1000);
    isPriceFilterActive = false;
    selectedCountry = null;
    selectedState = null;
    selectedCity = null;
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
    if (selectedCountry != null) {
      query = query.where('address.country', isEqualTo: selectedCountry);
    }
    if (selectedState != null) {
      query = query.where('address.state', isEqualTo: selectedState);
    }
    if (selectedCity != null) {
      query = query.where('address.city', isEqualTo: selectedCity);
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
    String? tempCountry = selectedCountry;
    String? tempState = selectedState;
    String? tempCity = selectedCity;
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
                    SizedBox(height: 8),
                    // CSC Picker Widget
                    CSCPicker(
                      layout: Layout.vertical,
                      flagState: CountryFlag.ENABLE,
                      dropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      disabledDropdownDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      countryDropdownLabel: "Select Country",
                      stateDropdownLabel: "Select State",
                      cityDropdownLabel: "Select City",

                      selectedItemStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      dropdownHeadingStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      dropdownItemStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      //                 defaultCountry: tempCountry != null
                      // ? DefaultCountry.values.firstWhere(
                      //     (c) => c.toString().split('.').last == tempCountry,
                      //     orElse: () => DefaultCountry.INDIA) // Changed to INDIA
                      // : DefaultCountry.INDIA, // Changed to INDIA

                      onCountryChanged: (country) {
                        setState(() => tempCountry = country);
                      },
                      onStateChanged: (state) {
                        setState(() => tempState = state);
                      },
                      onCityChanged: (city) {
                        setState(() => tempCity = city);
                      },
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
                      tempCountry = null;
                      tempState = null;
                      tempCity = null;
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
                    // Apply filters
                    priceRange = tempPriceRange;
                    isPriceFilterActive = tempIsPriceFilterActive;
                    selectedCountry = tempCountry;
                    selectedState = tempState;
                    selectedCity = tempCity;
                    selectedTimeFrame = tempTimeFrame;

                    Navigator.pop(context);
                    _loadingController.add(true);
                    await Future.delayed(Duration(seconds: 2));
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

  String _getEmptyStateMessage() {
    List<String> conditions = [];

    if (selectedCategory != null && selectedCategory != 'All') {
      conditions.add(selectedCategory!);
    }

    if (selectedCountry != null) {
      conditions.add('in $selectedCountry');
      if (selectedState != null) {
        conditions.add('$selectedState');
        if (selectedCity != null) {
          conditions.add('$selectedCity');
        }
      }
    }

    if (isPriceFilterActive) {
      conditions.add(
          'price range \$${priceRange.start.toStringAsFixed(0)} - \$${priceRange.end.toStringAsFixed(0)}');
    }

    if (conditions.isEmpty) {
      return 'No items found';
    }

    return 'No items found with ${conditions.join(", ")}';
  }

  void resetAllFilters() {
    priceRange = const RangeValues(0, 1000);
    isPriceFilterActive = false;
    selectedCity = null;
    selectedCountry = null;
    selectedTimeFrame = null;
    _loadingController.add(false);
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
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
}

class LocationPickerWidget extends StatefulWidget {
  final Function(Position position, Map<String, String> addressComponents)
      onLocationSelected;

  const LocationPickerWidget({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  _LocationPickerWidgetState createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await LocationServices.getCurrentLocation();
      final addressComponents = await LocationServices.getAddressComponents(
        LatLng(position.latitude, position.longitude),
      );
      widget.onLocationSelected(position, addressComponents);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _getCurrentLocation,
        icon: Icon(Icons.my_location),
        label: _isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Getting location...'),
                ],
              )
            : Text('Use Current Location'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class LocationServices {
  // Existing methods remain the same
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  static Future<LatLng> getCoordinatesFromAddress(String address) async {
    List<Location> locations = await locationFromAddress(address);
    return LatLng(locations.first.latitude, locations.first.longitude);
  }

  static Future<String> getAddressFromCoordinates(LatLng position) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    Placemark place = placemarks[0];
    return '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Add this new method to get address components
  static Future<Map<String, String>> getAddressComponents(
      LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];

      return {
        'street': place.street ?? '',
        'city': place.locality ?? '',
        'state': place.administrativeArea ?? '',
        'country': place.country ?? '',
        'postalCode': place.postalCode ?? '',
      };
    } catch (e) {
      print('Error getting address components: $e');
      return {
        'street': '',
        'city': '',
        'state': '',
        'country': '',
        'postalCode': '',
      };
    }
  }
}

class PopularItemsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: ViewCounterService.getPopularItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error loading items');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data?.docs ?? [];

        if (items.isEmpty) {
          return SizedBox.shrink();
        }

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Container(
                  width: 120,
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['images']?.isNotEmpty ?? false)
                        Expanded(
                          child: Image.network(
                            item['images'][0],
                            fit: BoxFit.cover,
                          ),
                        ),
                      SizedBox(height: 8),
                      Text(
                        item['name'] ?? 'Unnamed Item',
                        style: TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class ViewCounterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Increment view count for an item
  static Future<void> incrementViewCount(String itemId) async {
    try {
      // Get the current user
      final user = FirebaseAuth.instance.currentUser;

      // Create a unique view record to prevent duplicate counts from same user
      if (user != null) {
        final viewRef =
            _firestore.collection('item_views').doc('${itemId}_${user.uid}');

        final viewDoc = await viewRef.get();

        // Only count view if user hasn't viewed in last 24 hours
        if (!viewDoc.exists ||
            viewDoc
                .data()?['lastViewed']
                .toDate()
                .isBefore(DateTime.now().subtract(Duration(hours: 24)))) {
          // Update the view record
          await viewRef.set({
            'userId': user.uid,
            'itemId': itemId,
            'lastViewed': FieldValue.serverTimestamp(),
          });

          // Increment the item's view count
          await _firestore.collection('items').doc(itemId).update({
            'viewCount': FieldValue.increment(1),
            'lastViewed': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  // Get popular items
  static Stream<QuerySnapshot> getPopularItems({int limit = 10}) {
    return _firestore
        .collection('items')
        .orderBy('viewCount', descending: true)
        .limit(limit)
        .snapshots();
  }
}
