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
