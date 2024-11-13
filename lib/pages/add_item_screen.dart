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

class ItemWizard extends StatefulWidget {
  const ItemWizard({Key? key}) : super(key: key);

  @override
  _ItemWizardState createState() => _ItemWizardState();
}

class _ItemWizardState extends State<ItemWizard> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  int _remainingFeaturedItems = 0;
  bool _isPremiumPlan = false;

  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _addressController = TextEditingController();

  // Form Data
  String _selectedCategory = 'Cars';
  List<File> _selectedImages = [];
  bool _isFeatured = false;
  String? selectedCountry;
  String? selectedState;
  String? selectedCity;
  Position? _currentPosition;

  // Progress Indicator
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(
          5,
          (index) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Step 1: Location Details

  Future<void> _loadUserPlanDetails() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          setState(() {
            _isPremiumPlan = userDoc.data()?['isPremiumPlan'] ?? false;
            _remainingFeaturedItems =
                userDoc.data()?['remainingFeaturedItems'] ?? 3;
          });
        }
      }
    } catch (e) {
      print('Error loading user plan details: $e');
    }
  }

  void _navigateToUpgradePlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanUpgradeScreen(
          onPlanChanged: (isPremium) async {
            setState(() => _isPremiumPlan = isPremium);
            if (isPremium) {
              // Reset featured items limit for premium users
              await _updateUserPlanDetails(true, unlimited: true);
            }
          },
        ),
      ),
    );
  }

  Future<void> _updateUserPlanDetails(bool isPremium,
      {bool unlimited = false}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isPremiumPlan': isPremium,
        'remainingFeaturedItems': unlimited ? -1 : _remainingFeaturedItems,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // Step 2: Basic Item Details
  Widget _buildBasicDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Details',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Item Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.shopping_bag),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Price',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: Utils.categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedCategory = value!);
          },
        ),
      ],
    );
  }

  // Step 3: Images
  Widget _buildImagesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Photos',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Container(
          height: 200,
          child: _selectedImages.isEmpty
              ? _buildImagePickerButtons()
              : _buildImageGallery(),
        ),
      ],
    );
  }

  Widget _buildImagePickerButtons() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _takePicture(),
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 40),
                  Text('Take Photo'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => _pickImages(),
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 40),
                  Text('Upload Photos'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _selectedImages.length + 1,
      itemBuilder: (context, index) {
        if (index == _selectedImages.length) {
          return _buildAddMorePhotosButton();
        }
        return _buildImageThumbnail(index);
      },
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.all(8),
          width: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(_selectedImages[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedImages.removeAt(index);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddMorePhotosButton() {
    return InkWell(
      onTap: _showImageSourceDialog,
      child: Container(
        margin: EdgeInsets.all(8),
        width: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 40),
            Text('Add More'),
          ],
        ),
      ),
    );
  }

  // Step 4: Optional Details
  Widget _buildOptionalDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optional Details',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _brandController,
          decoration: InputDecoration(
            labelText: 'Brand (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.branding_watermark),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _warrantyController,
          decoration: InputDecoration(
            labelText: 'Warranty Details (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.security),
          ),
        ),
      ],
    );
  }

  // Step 5: Description and Featured Option

  // Modified _buildDescriptionStep to include plan information
  Widget _buildDescriptionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description & Featured Option',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Featured Listing',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!_isPremiumPlan)
                      TextButton(
                        onPressed: _navigateToUpgradePlan,
                        child: Text('Upgrade Plan'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_canUseFeatured())
                  CheckboxListTile(
                    title: Text('Make this a featured listing'),
                    subtitle: Text(
                        'Get more visibility and appear at the top of search results'),
                    value: _isFeatured,
                    onChanged: (value) {
                      setState(() => _isFeatured = value ?? false);
                    },
                  )
                else
                  ListTile(
                    title: Text(
                      'Featured listings not available',
                      style: TextStyle(color: Colors.grey),
                    ),
                    subtitle: Text(
                      'Upgrade to premium plan for unlimited featured listings',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                if (!_isPremiumPlan)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _remainingFeaturedItems > 0
                                ? 'Free Plan: $_remainingFeaturedItems featured listings remaining'
                                : 'Free Plan: No featured listings remaining',
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _canUseFeatured() {
    return _isPremiumPlan || _remainingFeaturedItems > 0;
  }

  // Modified _buildLocationStep to use LocationPickerWidget
  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Details',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        LocationPickerWidget(
          onLocationSelected: (address, lat, lng) {
            // Handle the selected location here
            print('Selected address: $address');
            print('Latitude: $lat, Longitude: $lng');
          },
        ),
      ],
    );
  }

  // Navigation
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              icon: Icon(Icons.arrow_back),
              label: Text('Back'),
              onPressed: () {
                setState(() => _currentStep--);
              },
            ),
          if (_currentStep < 4)
            ElevatedButton.icon(
              icon: Icon(Icons.arrow_forward),
              label: Text('Next'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() => _currentStep++);
                }
              },
            )
          else
            ElevatedButton.icon(
              icon: Icon(Icons.check),
              label: Text('Submit'),
              onPressed: _isLoading ? null : _submitItem,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Item'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: [
                    _buildLocationStep(),
                    _buildBasicDetailsStep(),
                    _buildImagesStep(),
                    _buildOptionalDetailsStep(),
                    _buildDescriptionStep(),
                  ][_currentStep],
                ),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

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
          onLocationSelected: (address, lat, lng) {
            // Handle the selected location here
            print('Selected address: $address');
            print('Latitude: $lat, Longitude: $lng');
          },
        ),
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

  // Add your existing helper methods here (_takePicture, _pickImages, _submitItem, etc.)
}
