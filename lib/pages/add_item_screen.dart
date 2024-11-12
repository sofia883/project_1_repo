import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path/path.dart' as path;
import 'package:intl_phone_number_input/intl_phone_number_input.dart'; // Import the package
import 'package:csc_picker/csc_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_1/services/location_service.dart';
import 'package:project_1/services/utils.dart';
import 'package:project_1/services/featured_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _brandController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _addressController = TextEditingController();

  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String _selectedCategory = 'Cars';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  String? selectedCountry;
  String? selectedState;
  String? selectedCity;
  Position? _currentPosition;
  bool _isFeatured = false;

  PhoneNumber? _phoneNumber; // Declare PhoneNumber variable

  final ImagePicker _picker = ImagePicker();
  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

// Update the camera method to match the style:
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // Reduced accuracy for speed
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    List<Future<String>> uploadTasks = [];

    try {
      // Check if user is authenticated
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      for (File imageFile in _selectedImages) {
        String fileName =
            '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';

        firebase_storage.Reference ref = firebase_storage
            .FirebaseStorage.instance
            .ref()
            .child('items')
            .child(fileName);

        // Add metadata with user ID
        firebase_storage.SettableMetadata metadata =
            firebase_storage.SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': currentUser.uid,
            'uploadedAt': DateTime.now().toString(),
          },
        );

        // Create upload task with error handling
        uploadTasks.add(ref
            .putFile(imageFile, metadata)
            .then((snapshot) => snapshot.ref.getDownloadURL())
            .catchError((error) {
          print('Error uploading image: $error');
          throw error;
        }));
      }

      // Upload all images in parallel
      imageUrls = await Future.wait(uploadTasks);
      return imageUrls;
    } catch (e) {
      if (e.toString().contains('unauthorized')) {
        throw Exception('Please sign in again to upload images');
      } else {
        throw Exception('Error uploading images: ${e.toString()}');
      }
    }
  }

// Modified submit function with better error handling
  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill all required fields and add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check authentication first
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in to add items');
      }

      // Refresh auth token if needed
      await currentUser.reload();
      final idToken = await currentUser.getIdToken(true);

      if (idToken == null) {
        throw Exception('Authentication error. Please sign in again.');
      }

      // Proceed with image upload and item creation
      final imageUrls = await _uploadImages();

      // Create item document
      final itemData = {
        'viewCount': 0,
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'phone': _phoneController.text.trim(),
        'brand': _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        'warranty': _warrantyController.text.trim().isEmpty
            ? null
            : _warrantyController.text.trim(),
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
        'status': 'Active',
        'isFeatured': _isFeatured,
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        'address': {
          'city': selectedCity,
          'state': selectedState,
          'country': selectedCountry,
        },
      };

      await FirebaseFirestore.instance.collection('items').add(itemData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully!')),
      );

      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      String errorMessage = 'Error adding item: ';

      if (e.toString().contains('unauthorized')) {
        errorMessage += 'Please sign in again to continue';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage += 'You don\'t have permission to perform this action';
      } else {
        errorMessage += e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _submitItem,
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InternationalPhoneNumberInput(
        onInputChanged: (PhoneNumber number) {
          _phoneNumber = number;
        },
        onInputValidated: (bool isValid) {
          print(isValid ? 'Valid phone number' : 'Invalid phone number');
        },
        selectorConfig: SelectorConfig(
          selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
          showFlags: true,
          setSelectorButtonAsPrefixIcon: true,
          useEmoji: true,
        ),
        searchBoxDecoration: InputDecoration(
          labelText: 'Search by country name or code',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
        spaceBetweenSelectorAndTextField: 0,
        ignoreBlank: false,
        autoValidateMode: AutovalidateMode.onUserInteraction,
        selectorTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
        initialValue: PhoneNumber(isoCode: 'IN'),
        textFieldController: _phoneController,
        formatInput: true,
        keyboardType: TextInputType.phone,
        inputBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
        ),
        inputDecoration: InputDecoration(
          hintText: 'Phone Number',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        LocationPickerWidget(
          onLocationSelected: (position, address) async {
            setState(() {
              _currentPosition = position;
              selectedCountry = address['country'];
              selectedState = address['state'];
              selectedCity = address['city'];
            });
          },
        ),
        // Only show CSC picker if location not selected via GPS
      ],
    );
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Item'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker section
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Images ListView
                    _selectedImages.isEmpty
                        ? Center(
                            child: Text('No images selected'),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 150,
                                    margin: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image:
                                            FileImage(_selectedImages[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.remove_circle),
                                        color: Colors.red,
                                        onPressed: () {
                                          setState(() {
                                            _selectedImages.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                    // Add More Images button - Always visible in the corner
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: _showImageSourceDialog,
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
              ),

              SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 16),
              _buildAddressSection(),
              SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: Utils.categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _brandController, // Optional field for brand
                decoration: InputDecoration(
                  labelText: 'Brand (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _warrantyController, // Optional field for warranty
                decoration: InputDecoration(
                  labelText: 'Warranty (if any, Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              SizedBox(height: 24),
              FeaturedItemWidget(
                onFeaturedChanged: (bool value) {
                  setState(() {
                    _isFeatured = value;
                  });
                },
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitItem,
                child:
                    _isLoading ? CircularProgressIndicator() : Text('Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _phoneController.clear();
    _addressController.clear();
    _brandController.clear();
    _warrantyController.clear();
    _postalCodeController.clear();
    _selectedImages.clear();
    setState(() {
      _selectedCategory = 'Cars';
      selectedCountry = null;
      selectedState = null;
      selectedCity = null;
    });
  }
}

class FeaturedItemWidget extends StatefulWidget {
  final Function(bool) onFeaturedChanged;

  FeaturedItemWidget({required this.onFeaturedChanged});

  @override
  _FeaturedItemWidgetState createState() => _FeaturedItemWidgetState();
}

class _FeaturedItemWidgetState extends State<FeaturedItemWidget> {
  bool _isFeatured = false;
  int _usedFeaturedItems = 0;
  final int _maxFreeFeaturedItems = 3;

  @override
  void initState() {
    super.initState();
    _loadUsedFeaturedItems();
  }

  Future<void> _loadUsedFeaturedItems() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('isFeatured', isEqualTo: true)
        .get();

    setState(() {
      _usedFeaturedItems = snapshot.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final remainingItems = _maxFreeFeaturedItems - _usedFeaturedItems;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Featured Item',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              remainingItems > 0
                  ? 'You have $remainingItems free featured items remaining'
                  : 'You have used all your free featured items',
            ),
            if (remainingItems <= 1) ...[
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Navigate to upgrade screen
                  Navigator.pushNamed(context, '/upgrade-plan');
                },
                child: Text('Upgrade to Premium'),
              ),
            ],
            CheckboxListTile(
              title: Text('Mark as Featured'),
              value: _isFeatured,
              onChanged: remainingItems > 0
                  ? (value) {
                      setState(() {
                        _isFeatured = value ?? false;
                        widget.onFeaturedChanged(_isFeatured);
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
