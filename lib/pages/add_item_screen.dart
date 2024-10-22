import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';

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
  final _scrollController = ScrollController();

  String _selectedCategory = 'Cars';
  List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  int _currentUploadIndex = 0;

  final List<String> _categories = [
    'Cars',
    'Chairs',
    'Shoes',
    'Electronics',
    'Books',
    'Clothing'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false;
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(Icons.camera_alt,
                          color: Theme.of(context).primaryColor),
                    ),
                    title: Text('Take a Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(Icons.photo_library,
                          color: Theme.of(context).primaryColor),
                    ),
                    title: Text('Choose from Gallery'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      if (source == ImageSource.camera) {
        final XFile? photo = await picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1800,
        );
        if (photo != null) {
          setState(() {
            _selectedImages.add(File(photo.path));
          });
        }
      } else {
        final List<XFile> images = await picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1800,
        );
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((xFile) => File(xFile.path)));
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking images: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<String> uploadImage(File imageFile) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('File does not exist');
      }

      // Get file size
      int fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        // 5MB limit
        throw Exception('File size too large');
      }

      // Create unique file name
      final String fileName =
          'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Create reference
      final Reference reference =
          FirebaseStorage.instance.ref().child('items').child(fileName);

      // Start upload with explicit content type
      final UploadTask uploadTask = reference.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploaded': 'true',
            'timestamp': DateTime.now().toString(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      }, onError: (error) {
        print('Upload error: $error');
      });

      // Wait for upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;

      // Get download URL
      final String downloadURL = await taskSnapshot.ref.getDownloadURL();
      print('Upload successful. Download URL: $downloadURL');

      return downloadURL;
    } catch (e) {
      print('Error in uploadImage: $e');
      rethrow;
    }
  }

// Usage in your _uploadImages function:
  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    for (File imageFile in _selectedImages) {
      try {
        String url = await uploadImage(imageFile);
        imageUrls.add(url);
      } catch (e) {
        print('Failed to upload image: $e');
        // Handle error appropriately
      }
    }
    return imageUrls;
  }

  Future<void> _submitItem() async {
    // Validate form and check if images are selected
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please fill all fields and add at least one image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Show upload progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading images...')),
      );

      // Upload images one by one
      List<String> imageUrls = await _uploadImages();

      // Parse the price safely
      final price = double.tryParse(_priceController.text.trim());
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid price')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Add the item to Firestore
      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('items').add({
        'name': _nameController.text.trim(),
        'price': price,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log the document ID to confirm the item was added
      print('Item added with ID: ${docRef.id}');

      // Clear the form and show success message
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item added successfully!')),
      );
    } catch (e) {
      // Log the error and show a SnackBar with the error message
      print('Error in _submitItem: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImages = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
            appBar: AppBar(
              title: Text('Add New Item'),
              elevation: 0,
            ),
            body: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Colors.white,
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Images Section
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _selectedImages.isEmpty
                              ? InkWell(
                                  onTap: _showImageSourceDialog,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 50,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Add Images',
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == _selectedImages.length) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: IconButton(
                                            onPressed: _showImageSourceDialog,
                                            icon: Icon(
                                              Icons.add_circle,
                                              size: 40,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return Stack(
                                      children: [
                                        Container(
                                          margin: EdgeInsets.all(8),
                                          width: 150,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            image: DecorationImage(
                                              image: FileImage(
                                                  _selectedImages[index]),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: IconButton(
                                              icon: Icon(Icons.remove_circle),
                                              color: Colors.red,
                                              onPressed: () {
                                                setState(() {
                                                  _selectedImages
                                                      .removeAt(index);
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        SizedBox(height: 24),

                        // Name Field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Item Name',
                            prefixIcon: Icon(Icons.shopping_bag),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter item name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Price Field
                        TextFormField(
                          controller: _priceController,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Price',
                            prefixIcon: Icon(Icons.currency_rupee),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Category Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.5)),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                            ),
                            items: _categories.map((String category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCategory = newValue;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 16),

                        // Description Field
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          minLines: 4,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter description';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _submitItem,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_shopping_cart),
                              SizedBox(width: 8),
                              Text(
                                'Add Item',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ])));
  }
}
