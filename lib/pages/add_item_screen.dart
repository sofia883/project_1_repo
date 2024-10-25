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
  final _addressController = TextEditingController();
  final _brandController = TextEditingController();
  final _warrantyController = TextEditingController();
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

  PhoneNumber? _phoneNumber; // Declare PhoneNumber variable
  final List<String> _categories = [
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

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];

    try {
      for (File imageFile in _selectedImages) {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';

        firebase_storage.Reference ref = firebase_storage
            .FirebaseStorage.instance
            .ref()
            .child('items')
            .child(fileName);

        await ref.putFile(
          imageFile,
          firebase_storage.SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploaded_by': 'app_user',
              'timestamp': DateTime.now().toString(),
            },
          ),
        );

        String downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }
    } catch (e) {
      print('Error uploading images: $e');
      throw e;
    }

    return imageUrls;
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please fill all required fields and add at least one image')),
      );
      return;
    }

    if (selectedCountry == null ||
        selectedState == null ||
        selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select country, state, and city')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      List<String> imageUrls = await _uploadImages();

      await FirebaseFirestore.instance.collection('items').add({
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
        'userId': currentUser.uid, // Add this line to store user ID
        'userPhone':
            _phoneController.text.trim(), // Add this line to store phone
        'status': 'Active', // Add this line to set initial status
        'address': {
          'street': _addressController.text.trim(),
          'city': selectedCity,
          'state': selectedState,
          'country': selectedCountry,
          'postalCode': _postalCodeController.text.trim(),
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item added successfully!')),
      );

      _clearForm();
    } catch (e) {
      print('Error submitting item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }

    try {
      final Position position = await LocationServices.getCurrentLocation();
      final LatLng itemLocation = LatLng(position.latitude, position.longitude);
      String formattedAddress =
          await LocationServices.getAddressFromCoordinates(itemLocation);

      await FirebaseFirestore.instance.collection('items').add({
        // ... your existing fields ...
        'location': GeoPoint(position.latitude, position.longitude),
        'formattedAddress': formattedAddress,
        'address': {
          'street': _addressController.text.trim(),
          'city': selectedCity,
          'state': selectedState,
          'country': selectedCountry,
          'postalCode': _postalCodeController.text.trim(),
          'coordinates': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          }
        },
      });
    } catch (e) {
      // ... error handling ...
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

  // Replace the address TextFormFields with CSC Picker
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
          // Update the address fields based on the selected location
          final addressComponents = await LocationServices.getAddressComponents(
            LatLng(position.latitude, position.longitude),
          );
          
          setState(() {
            selectedCountry = addressComponents['country'];
            selectedState = addressComponents['state'];
            selectedCity = addressComponents['city'];
          });
        },
      ),
      SizedBox(height: 16),
      CSCPicker(   layout: Layout.vertical,
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
          onCountryChanged: (country) {
            setState(() => selectedCountry = country);
          },
          onStateChanged: (state) {
            setState(() => selectedState = state);
          },
          onCityChanged: (city) {
            setState(() => selectedCity = city);
          },
        ),
        SizedBox(height: 16),
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

              _buildPhoneInput(), // Replace the old phone input with this new method

              SizedBox(height: 16),
              _buildAddressSection(),
              SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
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
