import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:csc_picker/csc_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:project_1/pages/detailed_screen.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:io';

class Utils {
  static final List<String> categories = [
    'All',
    'Cars',
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
    'Baby Products',
  ];
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
  Position? currentPosition;

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
    currentPosition = null;
  }

  void resetAllFilters() {
    priceRange = const RangeValues(0, 1000);
    isPriceFilterActive = false;
    selectedCity = null;
    selectedCountry = null;
    selectedTimeFrame = null;
    _loadingController.add(false);
  }

  Future<void> _getCurrentLocation(BuildContext context) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        selectedCity = place.locality;
        selectedState = place.administrativeArea;
        selectedCountry = place.country;
        currentPosition = position;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> showFilterBottomSheet(BuildContext context) async {
    RangeValues tempPriceRange = priceRange;
    bool tempIsPriceFilterActive = isPriceFilterActive;
    String? tempCountry = selectedCountry;
    String? tempState = selectedState;
    String? tempCity = selectedCity;
    String? tempTimeFrame = selectedTimeFrame;
    String? tempFormattedAddress;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Options',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
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
                        SizedBox(height: 20),
                        Text('Location',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        LocationPickerWidget(
                          onLocationSelected: (address, lat, lng) {
                            // Handle the selected location here
                            print('Selected address: $address');
                            print('Latitude: $lat, Longitude: $lng');
                          },
                        ),
                        SizedBox(height: 20),
                        Text('Time Frame',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: tempTimeFrame,
                          isExpanded: true,
                          hint: Text('Select Time Frame'),
                          items: [
                            DropdownMenuItem(
                                value: null, child: Text('All Time')),
                            ...timeFrames.keys.map((String time) {
                              return DropdownMenuItem(
                                  value: time, child: Text(time));
                            }).toList(),
                          ],
                          onChanged: (value) =>
                              setState(() => tempTimeFrame = value),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                                  tempFormattedAddress = null;
                                });
                              },
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: Text('Apply Filters'),
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
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
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
  final Function(String address, double lat, double lng) onLocationSelected;

  const LocationPickerWidget({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  _LocationPickerWidgetState createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  String? selectedAddress;
  bool isLoading = false;
  bool isSaving = false;

  // CSC Picker state
  String? selectedCountry;
  String? selectedState;
  String? selectedCity;

  void _showLocationOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Location Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.my_location),
              title: Text('Use Current Location'),
              onTap: () {
                Navigator.pop(context);
                _getCurrentLocation();
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_location),
              title: Text('Add Manually'),
              onTap: () {
                Navigator.pop(context);
                _showManualLocationPicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get isCSCComplete =>
      selectedCountry != null && selectedState != null && selectedCity != null;

  void _showManualLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter Location Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              CSCPicker(
                showStates: true,
                showCities: true,
                flagState: CountryFlag.ENABLE,
                dropdownDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                onCountryChanged: (country) {
                  setState(() {
                    selectedCountry = country;
                    selectedState = null;
                    selectedCity = null;
                  });
                },
                onStateChanged: (state) {
                  setState(() {
                    selectedState = state;
                    selectedCity = null;
                  });
                },
                onCityChanged: (city) {
                  setState(() {
                    selectedCity = city;
                  });
                },
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !isCSCComplete || isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          await Future.delayed(Duration(seconds: 1));
                          final address =
                              '$selectedCity, $selectedState, $selectedCountry';
                          this.setState(() {
                            selectedAddress = address;
                            isSaving = false;
                          });
                          widget.onLocationSelected(address, 0, 0);
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCSCComplete
                        ? Colors.orange
                        : null, // Set color to orange
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text('Save Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '${place.street}, ${place.locality}, ${place.country}';
        setState(() {
          selectedAddress = address;
        });

        _showMapScreen(position);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showMapScreen(Position position) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Confirm Location'),
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(position.latitude, position.longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('current'),
                    position: LatLng(position.latitude, position.longitude),
                  ),
                },
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedAddress ?? '',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setState(() => isSaving = true);
                                    await Future.delayed(Duration(seconds: 1));
                                    widget.onLocationSelected(
                                      selectedAddress!,
                                      position.latitude,
                                      position.longitude,
                                    );
                                    setState(() => isSaving = false);
                                    Navigator.pop(context);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: isSaving
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text('Confirm Location'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _showLocationOptions,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Icon(Icons.location_on),
            SizedBox(width: 8),
            if (isLoading)
              SizedBox(
                height: 16,
                width: 16,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
              )
            else
              Expanded(
                child: Text(
                  selectedAddress ?? 'Select Location',
                  style:
                      TextStyle(color: Colors.black), // Set text color to black
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PopularItemsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: ViewCounterService.getPopularItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading items'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final items = snapshot.data?.docs ?? [];

        if (items.isEmpty) {
          return SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Popular Items',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final doc = items[index];
                final item = doc.data() as Map<String, dynamic>;

                // Get category and location for finding related items
                final category = item['category'] ?? '';
                final city = item['address']?['city'] ?? '';
                final state = item['address']?['state'] ?? '';

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
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
                                  child: Icon(Icons.image),
                                ),
                              ),
                            )
                          : Icon(Icons.image_not_supported, size: 30),
                    ),
                    title: Text(
                      item['name'] ?? 'Unnamed Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item['address']['city']}, ${item['address']['state']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      // Get related items before navigation
                      final relatedItemsQuery = await FirebaseFirestore.instance
                          .collection('items')
                          .where('category', isEqualTo: category)
                          .where('address.city', isEqualTo: city)
                          .where('address.state', isEqualTo: state)
                          .where(FieldPath.documentId, isNotEqualTo: doc.id)
                          .limit(10)
                          .get();

                      final relatedItems = relatedItemsQuery.docs;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailedResultScreen(
                            selectedDoc: doc,
                            allDocs: relatedItems,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ViewCounterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logItemView(String itemId) async {
    try {
      // First increment the viewCount in the items collection
      await _firestore.collection('items').doc(itemId).update({
        'viewCount': FieldValue.increment(1),
      });

      final user = FirebaseAuth.instance.currentUser;
      final timestamp = FieldValue.serverTimestamp();

      if (user != null) {
        // For authenticated users, create a unique view record
        final viewId =
            '${itemId}_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
        await _firestore.collection('item_views').doc(viewId).set({
          'userId': user.uid,
          'itemId': itemId,
          'timestamp': timestamp,
        });
      } else {
        // For anonymous users, update daily count
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        final anonymousViewRef =
            _firestore.collection('anonymous_views').doc('${itemId}_$dateStr');

        await anonymousViewRef.set({
          'itemId': itemId,
          'count': FieldValue.increment(1),
          'lastUpdated': timestamp,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error logging view: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot> getPopularItems({int limit = 10}) {
    return _firestore
        .collection('items')
        .orderBy('viewCount', descending: true)
        .limit(limit)
        .snapshots();
  }
}

class ImageGallery extends StatefulWidget {
  final List<dynamic> images;
  final double height;
  final bool isEditable;
  final Function(int)? onDelete;
  final VoidCallback? onAddImages;
  final bool showAddButton;

  const ImageGallery({
    Key? key,
    required this.images,
    this.height = 200,
    this.isEditable = false,
    this.onDelete,
    this.onAddImages,
    this.showAddButton = false,
  }) : super(key: key);

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  final PageController _pageController = PageController();
  int _currentPage = 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Main Image Display
          widget.images.isEmpty
              ? Center(
                  child: Text('No images available'),
                )
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page + 1;
                    });
                  },
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: _getImageProvider(widget.images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Delete Button (only shown in editable mode)
                        if (widget.isEditable && widget.onDelete != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.remove_circle),
                                color: Colors.red,
                                onPressed: () => widget.onDelete!(index),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

          // Dot Indicators - Only show when there's more than one image
          if (widget.images.length > 1)
            Positioned(
              bottom: widget.showAddButton ? 48 : 16,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.images.length,
                  effect: WormEffect(
                    dotWidth: 8,
                    dotHeight: 8,
                    activeDotColor: Theme.of(context).primaryColor,
                    dotColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ),

          // Image Counter - Only show when there are multiple images
          if (widget.images.length > 1) // Changed condition here
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_currentPage/${widget.images.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // Add Images Button (only shown in editable mode)
          if (widget.showAddButton && widget.onAddImages != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: widget.onAddImages,
                  icon: Icon(
                    Icons.add_photo_alternate,
                    color: Colors.white,
                  ),
                  tooltip: 'Add More Images',
                ),
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider _getImageProvider(dynamic image) {
    if (image is File) {
      return FileImage(image);
    } else if (image is String) {
      return NetworkImage(image);
    } else {
      throw Exception('Unsupported image type');
    }
  }
}

// New PlanUpgradeScreen widget
class PlanUpgradeScreen extends StatefulWidget {
  final Function(bool isPremium) onPlanChanged;

  const PlanUpgradeScreen({Key? key, required this.onPlanChanged})
      : super(key: key);

  @override
  _PlanUpgradeScreenState createState() => _PlanUpgradeScreenState();
}

class _PlanUpgradeScreenState extends State<PlanUpgradeScreen> {
  bool _isPremiumEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrade Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Premium Plan Features',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.star, color: Colors.orange),
                      title: Text('Unlimited Featured Listings'),
                    ),
                    ListTile(
                      leading: Icon(Icons.visibility, color: Colors.orange),
                      title: Text('Priority in Search Results'),
                    ),
                    ListTile(
                      leading: Icon(Icons.analytics, color: Colors.orange),
                      title: Text('Advanced Analytics'),
                    ),
                    SwitchListTile(
                      title: Text('Enable Premium Plan'),
                      subtitle: Text('Toggle for testing purposes'),
                      value: _isPremiumEnabled,
                      onChanged: (value) {
                        setState(() => _isPremiumEnabled = value);
                        widget.onPlanChanged(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}