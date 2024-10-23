import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path/path.dart' as path;
import 'package:intl_phone_number_input/intl_phone_number_input.dart'; // Import the package

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

  String _selectedCategory = 'Cars';
  List<File> _selectedImages = [];
  bool _isLoading = false;

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

    setState(() => _isLoading = true);

    try {
      List<String> imageUrls = await _uploadImages();

      await FirebaseFirestore.instance.collection('items').add({
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'brand': _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(), // Optional field
        'warranty': _warrantyController.text.trim().isEmpty
            ? null
            : _warrantyController.text.trim(), // Optional field
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
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
                child: _selectedImages.isEmpty
                    ? Center(
                        child: TextButton.icon(
                          onPressed: () => _pickImages(),
                          icon: Icon(Icons.add_photo_alternate),
                          label: Text('Add Images'),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _selectedImages.length) {
                            return Center(
                              child: IconButton(
                                onPressed: () => _pickImages(),
                                icon: Icon(Icons.add_photo_alternate),
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.file(
                                  _selectedImages[index],
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
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
                            ],
                          );
                        },
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

              InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  print('Phone number: $number'); // Debugging output
                  _phoneNumber = number; // Update the phone number variable
                },
                onInputValidated: (bool isValid) {
                  print(
                      isValid ? 'Valid phone number' : 'Invalid phone number');
                },
                selectorConfig: const SelectorConfig(
                  selectorType: PhoneInputSelectorType.DROPDOWN,
                ),
                ignoreBlank: false,
                autoValidateMode:
                    AutovalidateMode.disabled, // Disable auto validation
                selectorTextStyle: TextStyle(color: Colors.black),
                initialValue:
                    PhoneNumber(isoCode: 'IN'), // Default to Indian code
                textFieldController:
                    _phoneController, // Make sure to use the controller
                formatInput: true, // Try formatting the input
                keyboardType: TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                inputBorder: OutlineInputBorder(),
              ),

              SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
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
    _priceController.clear;

    _descriptionController.clear();
    _phoneController.clear();
    _addressController.clear();
    _brandController.clear(); // Clear brand
    _warrantyController.clear(); // Clear warranty
    _selectedImages.clear();
    setState(() {
      _selectedCategory = 'Cars'; // Reset category
    });
  }
}
