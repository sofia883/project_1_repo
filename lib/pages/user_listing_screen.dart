import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserListings extends StatelessWidget {
  final User? user;

  const UserListings({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (user == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildListingsHeader(context),
        _buildListingsStream(),
      ],
    );
  }

  Widget _buildListingsHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Listings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('New Listing'),
            onPressed: () => Navigator.pushNamed(context, '/add-listing'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final listings = snapshot.data!.docs;

        if (listings.isEmpty) {
          return _buildEmptyListingsWidget(context);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: listings.length,
          itemBuilder: (context, index) => _buildListingItem(
            context,
            listings[index].id,
            listings[index].data() as Map<String, dynamic>,
          ),
        );
      },
    );
  }

  Widget _buildListingItem(
      BuildContext context, String itemId, Map<String, dynamic> listing) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: _buildListingImage(listing),
        title: Text(
          listing['name'] ?? 'Unnamed Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\$${(listing['price'] ?? 0).toStringAsFixed(2)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            _buildStatusChip(context, listing['status'] ?? 'Active'),
          ],
        ),
        trailing: _buildListingMenu(context, itemId, listing),
        onTap: () => _viewListingDetails(context, itemId, listing),
      ),
    );
  }

  Widget _buildListingImage(Map<String, dynamic> listing) {
    final imageUrl = listing['images']?.isNotEmpty == true 
        ? listing['images'][0] 
        : null;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.error, color: Colors.red),
              )
            : Icon(Icons.image, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color chipColor;
    IconData iconData;

    switch (status.toLowerCase()) {
      case 'sold':
        chipColor = Colors.green;
        iconData = Icons.check_circle;
        break;
      case 'pending':
        chipColor = Colors.orange;
        iconData = Icons.access_time;
        break;
      default:
        chipColor = Colors.blue;
        iconData = Icons.local_offer;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: chipColor),
          SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingMenu(
      BuildContext context, String itemId, Map<String, dynamic> listing) {
    return PopupMenuButton(
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.pop(context);
              _editListing(context, itemId, listing);
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(
              listing['status'] == 'Sold' ? Icons.undo : Icons.sell,
              color: Colors.green,
            ),
            title: Text(
              listing['status'] == 'Sold'
                  ? 'Mark as Available'
                  : 'Mark as Sold',
              style: TextStyle(color: Colors.green),
            ),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.pop(context);
              _toggleListingStatus(context, itemId, listing);
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, itemId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyListingsWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined,
                size: 64, color: Theme.of(context).disabledColor),
            SizedBox(height: 16),
            Text(
              'No Listings Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              'Start selling by creating your first listing',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Create First Listing'),
              onPressed: () => Navigator.pushNamed(context, '/add-listing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text('Error loading listings: $error'),
          ],
        ),
      ),
    );
  }

  void _viewListingDetails(
      BuildContext context, String itemId, Map<String, dynamic> listing) {
    Navigator.pushNamed(
      context,
      '/listing-details',
      arguments: {'itemId': itemId, 'listing': listing},
    );
  }

  void _editListing(
      BuildContext context, String itemId, Map<String, dynamic> listing) {
    Navigator.pushNamed(
      context,
      '/edit-listing',
      arguments: {'itemId': itemId, 'listing': listing},
    );
  }

  Future<void> _toggleListingStatus(
      BuildContext context, String itemId, Map<String, dynamic> listing) async {
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
        SnackBar(
          content: Text('Error updating item status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, String itemId) async {
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
          SnackBar(
            content: Text('Error deleting listing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}