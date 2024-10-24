import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddAdvertisementScreen extends StatefulWidget {
  @override
  _AddAdvertisementScreenState createState() => _AddAdvertisementScreenState();
}

class _AddAdvertisementScreenState extends State<AddAdvertisementScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Form fields
  String _title = '';
  String _description = '';
  String _link = '';
  DateTime? _expiryDate;
  File? _imageFile;
  bool _isLoading = false;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.orange),
                title: Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.orange),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      String fileName = 'ads/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields and add an image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final imageUrl = await _uploadImage();
      if (imageUrl == null) throw 'Failed to upload image';

      await _firestore.collection('ads').add({
        'title': _title,
        'description': _description,
        'imageUrl': imageUrl,
        'link': _link,
        'expiryDate': _expiryDate,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Advertisement added successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding advertisement: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Advertisement'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: _showImageSourceOptions,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 50),
                                  SizedBox(height: 8),
                                  Text('Add Advertisement Image'),
                                  Text('(Tap to choose camera or gallery)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      )),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Rest of the form fields remain the same...
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Advertisement Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter a title'
                          : null,
                      onSaved: (value) => _title = value ?? '',
                      onChanged: (value) => _title = value,
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Please enter a description'
                          : null,
                      onSaved: (value) => _description = value ?? '',
                      onChanged: (value) => _description = value,
                    ),
                    SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Link (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (value) => _link = value ?? '',
                      onChanged: (value) => _link = value,
                    ),
                    SizedBox(height: 16),

                    ListTile(
                      title: Text(_expiryDate == null
                          ? 'Select Expiry Date (Optional)'
                          : 'Expires on: ${_expiryDate!.toLocal().toString().split(' ')[0]}'),
                      trailing: Icon(Icons.calendar_today),
                      tileColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _expiryDate = picked;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _submitAd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Post Advertisement',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
