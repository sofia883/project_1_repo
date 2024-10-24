import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'user_listing_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isDarkMode = false;
  bool _isLoading = false;
  String _error = '';
  final ImagePicker _picker = ImagePicker();

  // Controllers for editing profile
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Initialize with Firebase Auth data
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userData.exists) {
        setState(() {
          _nameController.text = userData.data()?['name'] ?? '';
          _locationController.text = userData.data()?['location'] ?? '';
          _bioController.text = userData.data()?['bio'] ?? '';
          if (_emailController.text.isEmpty) {
            _emailController.text = userData.data()?['email'] ?? '';
          }
          if (_phoneController.text.isEmpty) {
            _phoneController.text = userData.data()?['phone'] ?? '';
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading profile: $e';
      });
      _showErrorSnackBar(_error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user!.uid}.jpg');

      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();

      await user!.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'profilePicture': downloadUrl});

      setState(() => _isLoading = false);
      _showSuccessSnackBar('Profile picture updated successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error updating profile picture: $e';
      });
      _showErrorSnackBar(_error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _showEditProfileDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    _buildUserDetails(),
                    _buildSettingsSection(),
                    _buildMyListingsSection()
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 18,
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    onPressed: _updateProfilePicture,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Add Your Name',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (_locationController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 16),
                  SizedBox(width: 4),
                  Text(
                    _locationController.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          if (_bioController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                _bioController.text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserDetails() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email'),
              subtitle: Text(_emailController.text.isNotEmpty
                  ? _emailController.text
                  : 'Not provided'),
              trailing: user?.emailVerified == true
                  ? Icon(Icons.verified, color: Colors.green)
                  : null,
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Phone'),
              subtitle: Text(_phoneController.text.isNotEmpty
                  ? _phoneController.text
                  : 'Not provided'),
              trailing: user?.phoneNumber != null
                  ? Icon(Icons.verified, color: Colors.green)
                  : TextButton(
                      onPressed: () {
                        // Navigate to phone verification screen
                        Navigator.pushNamed(context, '/verify-phone');
                      },
                      child: Text('Verify'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  enabled: user?.phoneNumber == null,
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    prefixIcon: Icon(Icons.info),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .set({
                    'name': _nameController.text,
                    'phone': _phoneController.text,
                    'location': _locationController.text,
                    'bio': _bioController.text,
                    'email': user?.email,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  Navigator.pop(context);
                  setState(() {});
                  _showSuccessSnackBar('Profile updated successfully');
                } catch (e) {
                  _showErrorSnackBar('Error updating profile: $e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.dark_mode),
            title: Text('Dark Mode'),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (value) {
                setState(() => _isDarkMode = value);
                // Implement theme change in your app's theme provider
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            onTap: () {
              Navigator.pushNamed(context, '/notifications-settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.security),
            title: Text('Privacy & Security'),
            onTap: () {
              Navigator.pushNamed(context, '/privacy-settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Logout', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildMyListingsSection() {
    return UserListings(user: user);
  }

  Widget _buildListingImage(Map<String, dynamic> listing) {
    final imageUrl =
        listing['images']?.isNotEmpty == true ? listing['images'][0] : null;

    if (imageUrl == null) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.error),
          );
        },
      ),
    );
  }

  Future<void> _toggleListingStatus(
      String itemId, Map<String, dynamic> listing) async {
    try {
      final newStatus = listing['status'] == 'Sold' ? 'Active' : 'Sold';
      await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item marked as $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item status: $e')),
      );
    }
  }

  void _editListing(String itemId, Map<String, dynamic> listing) {
    // Navigate to edit listing screen with the current listing data
    Navigator.pushNamed(
      context,
      '/edit-listing',
      arguments: {
        'itemId': itemId,
        'listing': listing,
      },
    );
  }

  // Rest of your existing code...

  // Widget _buildProfileHeader() {
  //   return Container(
  //     padding: EdgeInsets.all(16),
  //     child: Column(
  //       children: [
  //         Stack(
  //           children: [
  //             CircleAvatar(
  //               radius: 50,
  //               backgroundImage: user?.photoURL != null
  //                   ? NetworkImage(user!.photoURL!)
  //                   : null,
  //               child: user?.photoURL == null
  //                   ? Icon(Icons.person, size: 50)
  //                   : null,
  //             ),
  //             Positioned(
  //               bottom: 0,
  //               right: 0,
  //               child: CircleAvatar(
  //                 backgroundColor: Theme.of(context).primaryColor,
  //                 radius: 18,
  //                 child: IconButton(
  //                   icon: Icon(Icons.camera_alt, size: 18, color: Colors.white),
  //                   onPressed: () {
  //                     // Implement profile photo change
  //                   },
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         SizedBox(height: 16),
  //         Text(
  //           _nameController.text,
  //           style: Theme.of(context).textTheme.headlineSmall,
  //         ),
  //         if (_locationController.text.isNotEmpty)
  //           Text(
  //             _locationController.text,
  //             style: Theme.of(context).textTheme.bodyLarge,
  //           ),
  //         SizedBox(height: 8),
  //         if (_bioController.text.isNotEmpty)
  //           Text(
  //             _bioController.text,
  //             textAlign: TextAlign.center,
  //             style: Theme.of(context).textTheme.bodyMedium,
  //           ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildUserDetails() {
  //   return Card(
  //     margin: EdgeInsets.all(16),
  //     child: Padding(
  //       padding: EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             'Contact Information',
  //             style: Theme.of(context).textTheme.titleLarge,
  //           ),
  //           SizedBox(height: 16),
  //           ListTile(
  //             leading: Icon(Icons.email),
  //             title: Text('Email'),
  //             subtitle: Text(_emailController.text.isNotEmpty
  //                 ? _emailController.text
  //                 : 'Not provided'),
  //           ),
  //           ListTile(
  //             leading: Icon(Icons.phone),
  //             title: Text('Phone'),
  //             subtitle: Text(_phoneController.text.isNotEmpty
  //                 ? _phoneController.text
  //                 : 'Not provided'),
  //           ),
  //           if (user?.emailVerified == true)
  //             Chip(
  //               label: Text('Email Verified'),
  //               avatar: Icon(Icons.verified, size: 16),
  //               backgroundColor: Colors.green[100],
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Future<void> _showEditProfileDialog() async {
  //   await showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Edit Profile'),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(
  //               controller: _nameController,
  //               decoration: InputDecoration(
  //                 labelText: 'Name',
  //                 prefixIcon: Icon(Icons.person),
  //               ),
  //             ),
  //             SizedBox(height: 8),
  //             TextField(
  //               controller: _phoneController,
  //               decoration: InputDecoration(
  //                 labelText: 'Phone',
  //                 prefixIcon: Icon(Icons.phone),
  //               ),
  //               enabled: user?.phoneNumber ==
  //                   null, // Only allow editing if not set in Auth
  //             ),
  //             SizedBox(height: 8),
  //             TextField(
  //               controller: _locationController,
  //               decoration: InputDecoration(
  //                 labelText: 'Location',
  //                 prefixIcon: Icon(Icons.location_on),
  //               ),
  //             ),
  //             SizedBox(height: 8),
  //             TextField(
  //               controller: _bioController,
  //               decoration: InputDecoration(
  //                 labelText: 'Bio',
  //                 prefixIcon: Icon(Icons.info),
  //               ),
  //               maxLines: 3,
  //             ),
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           child: Text('Cancel'),
  //           onPressed: () => Navigator.pop(context),
  //         ),
  //         TextButton(
  //           child: Text('Save'),
  //           onPressed: () async {
  //             try {
  //               await FirebaseFirestore.instance
  //                   .collection('users')
  //                   .doc(user?.uid)
  //                   .set({
  //                 'name': _nameController.text,
  //                 'phone': _phoneController.text,
  //                 'location': _locationController.text,
  //                 'bio': _bioController.text,
  //                 'email': user?.email, // Store email from Auth
  //               }, SetOptions(merge: true));
  //               Navigator.pop(context);
  //               setState(() {});
  //             } catch (e) {
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(content: Text('Error updating profile: $e')),
  //               );
  //             }
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildSettingsSection() {
  //   return Column(
  //     children: [
  //       ListTile(
  //         leading: Icon(Icons.dark_mode),
  //         title: Text('Dark Mode'),
  //         trailing: Switch(
  //           value: _isDarkMode,
  //           onChanged: (value) {
  //             setState(() => _isDarkMode = value);
  //             // Implement theme change
  //           },
  //         ),
  //       ),
  //       ListTile(
  //         leading: Icon(Icons.notifications),
  //         title: Text('Notifications'),
  //         onTap: () {
  //           // Navigate to notifications settings
  //         },
  //       ),
  //       ListTile(
  //         leading: Icon(Icons.security),
  //         title: Text('Privacy & Security'),
  //         onTap: () {
  //           // Navigate to privacy settings
  //         },
  //       ),
  //     ],
  //   );
  // }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text('Are you sure you want to delete your account?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    Future<void> _confirmDelete(String itemId) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Listing'),
          content: Text('Are you sure you want to delete this listing?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await FirebaseFirestore.instance
              .collection('items')
              .doc(itemId)
              .delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Listing deleted successfully')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting listing: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Listing'),
        content: Text('Are you sure you want to delete this listing?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listing deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting listing: $e')),
        );
      }
    }
  }
}
