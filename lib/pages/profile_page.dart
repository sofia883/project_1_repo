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
  bool _showUpgradePrompt = false;
  int _remainingFreeListings = 3;
  DateTime? _planExpiryDate;

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
    _checkSubscriptionStatus();
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phoneNumber ?? '';
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

  Future<void> _checkSubscriptionStatus() async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final subscriptionStatus = userData['subscriptionStatus'] ?? 'free';
      final lastPostDate = userData['lastPostDate']?.toDate();

      if (subscriptionStatus == 'free') {
        final listings = await FirebaseFirestore.instance
            .collection('items')
            .where('userId', isEqualTo: user!.uid)
            .where('postDate',
                isGreaterThan: DateTime.now().subtract(Duration(days: 28)))
            .get();

        setState(() {
          _remainingFreeListings = 3 - listings.docs.length;
          if (_remainingFreeListings <= 0) {
            _showUpgradePrompt = true;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _showEditProfileDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        _buildSubscriptionStatus(),
                        _buildUserDetails(),
                        _buildSettingsSection(),
                        _buildMyListingsSection(),
                      ],
                    ),
                  ),
                ),
                if (_showUpgradePrompt) _buildUpgradeOverlay(),
              ],
            ),
    );
  }

  Widget _buildSubscriptionStatus() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Current Plan: ${_remainingFreeListings > 0 ? "Free Plan" : "Free Plan (Limit Reached)"}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Remaining Free Listings: $_remainingFreeListings',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade700,
            ),
          ),
          SizedBox(height: 16),
          if (_remainingFreeListings <= 1)
            ElevatedButton.icon(
              icon: Icon(Icons.star),
              label: Text('Upgrade to Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _showUpgradePlan,
            ),
        ],
      ),
    );
  }

  Widget _buildUpgradeOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Card(
          margin: EdgeInsets.all(32),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium,
                  size: 64,
                  color: Colors.blue.shade700,
                ),
                SizedBox(height: 16),
                Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'You\'ve reached your free plan limit.\nUpgrade to continue posting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Upgrade Now'),
                  onPressed: _showUpgradePlan,
                ),
                TextButton(
                  child: Text('Maybe Later'),
                  onPressed: () {
                    setState(() => _showUpgradePrompt = false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUpgradePlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose Your Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanCard(
              title: 'Monthly Premium',
              price: '\$9.99/month',
              features: [
                'Unlimited Listings',
                'Priority Support',
                'Featured Listings',
                'Advanced Analytics'
              ],
              onSelect: () => _processPurchase('monthly'),
            ),
            SizedBox(height: 16),
            _buildPlanCard(
              title: 'Annual Premium',
              price: '\$99.99/year',
              features: [
                'All Monthly Features',
                '2 Months Free',
                'Early Access to New Features',
                'Premium Badge'
              ],
              onSelect: () => _processPurchase('annual'),
              isPopular: true,
            ),
          ],
        ),
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

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required Function() onSelect,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular ? Colors.blue.shade700 : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Text(
                'Most Popular',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.blue.shade700,
                  ),
                ),
                SizedBox(height: 16),
                ...features.map((feature) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                          SizedBox(width: 8),
                          Text(feature),
                        ],
                      ),
                    )),
                SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPopular ? Colors.blue.shade700 : Colors.grey.shade200,
                    foregroundColor:
                        isPopular ? Colors.white : Colors.blue.shade700,
                  ),
                  child: Text('Select Plan'),
                  onPressed: onSelect,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPurchase(String planType) async {
    // Implement your payment processing logic here
    // After successful payment:
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'subscriptionStatus': 'premium',
        'planType': planType,
        'subscriptionStartDate': FieldValue.serverTimestamp(),
        'subscriptionEndDate': planType == 'monthly'
            ? DateTime.now().add(Duration(days: 30))
            : DateTime.now().add(Duration(days: 365)),
      });

      setState(() {
        _showUpgradePrompt = false;
        _remainingFreeListings = -1; // Indicates premium status
      });

      Navigator.of(context).pop();
      _showSuccessSnackBar('Successfully upgraded to premium!');
    } catch (e) {
      _showErrorSnackBar('Error processing purchase: $e');
    }
  }

  // ... (rest of your existing code)

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
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _showDeleteAccountConfirmationDialog,
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
      // Replace all routes with the initial route which will automatically
      // redirect to login screen due to auth state change
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Show loading indicator
      setState(() => _isLoading = true);

      // 1. First delete chats and messages since we need auth for permissions
      final userChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .get();

      for (var chat in userChats.docs) {
        // Delete all messages in the chat
        final messages = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chat.id)
            .collection('messages')
            .get(); // Remove the sender filter to get all messages

        // Batch delete messages
        final batch = FirebaseFirestore.instance.batch();
        for (var message in messages.docs) {
          batch.delete(message.reference);
        }
        await batch.commit();

        // Delete the chat document
        await chat.reference.delete();
      }

      // 2. Delete all user's listings and their images from Storage
      final userListings = await FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in userListings.docs) {
        final listingData = doc.data();
        if (listingData['images'] != null) {
          for (String imageUrl in listingData['images']) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(imageUrl);
              await ref.delete();
            } catch (e) {
              print('Error deleting image: $e');
            }
          }
        }
        await doc.reference.delete();
      }

      // 3. Delete profile picture from Storage if exists
      if (user.photoURL != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_pictures')
              .child('${user.uid}.jpg');
          await ref.delete();
        } catch (e) {
          print('Error deleting profile picture: $e');
        }
      }

      // 4. Delete user document from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // 5. Delete user authentication account
      await user.delete();

      // 6. Sign out to clear any remaining auth state
      await FirebaseAuth.instance.signOut();

      // 7. Show success message and navigate to login
      if (mounted) {
        // Check if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account successfully deleted'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login screen and clear all routes
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', // Your login route
          (route) => false, // This removes all routes from the stack
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if widget is still mounted
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must choose an option
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete your account?'),
            SizedBox(height: 16),
            Text(
              'This action will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Delete all your listings and images'),
            Text('• Remove your profile and personal data'),
            Text('• Delete your messages and chats'),
            Text('• Permanently delete your account'),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Widget _buildMyListingsSection() {
    return UserListings(user: user);
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
