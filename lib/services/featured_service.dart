import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeaturedService {
  static const int FREE_TRIAL_LIMIT = 3;
  static const int FEATURED_DAYS_LIMIT = 28;

  static Future<Map<String, dynamic>> getFeaturedStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return {'remainingAds': 0, 'hasActivePlan': false};

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      // Initialize user's featured status if it doesn't exist
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'featuredItemsUsed': 0,
        'hasActivePlan': false,
        'featuredItems': [],
      });
      return {'remainingAds': FREE_TRIAL_LIMIT, 'hasActivePlan': false};
    }

    final data = userDoc.data() as Map<String, dynamic>;
    final featuredItemsUsed = data['featuredItemsUsed'] ?? 0;
    final hasActivePlan = data['hasActivePlan'] ?? false;

    if (hasActivePlan) {
      return {'remainingAds': -1, 'hasActivePlan': true}; // Unlimited with plan
    }

    return {
      'remainingAds': FREE_TRIAL_LIMIT - featuredItemsUsed,
      'hasActivePlan': false
    };
  }

  static Future<bool> canAddFeaturedItem() async {
    final status = await getFeaturedStatus();
    return status['remainingAds'] > 0 || status['hasActivePlan'];
  }

  static Future<void> addFeaturedItem(String itemId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Add to featured items collection
    await FirebaseFirestore.instance.collection('featuredItems').add({
      'itemId': itemId,
      'userId': userId,
      'startDate': FieldValue.serverTimestamp(),
      'expiryDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: FEATURED_DAYS_LIMIT))),
    });

    // Update user's featured items count if not on paid plan
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userDoc.data()?['hasActivePlan']) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'featuredItemsUsed': FieldValue.increment(1),
      });
    }
  }

  static Stream<QuerySnapshot> getFeaturedItems() {
    return FirebaseFirestore.instance
        .collection('featuredItems')
        .where('expiryDate', isGreaterThan: Timestamp.now())
        .orderBy('expiryDate', descending: true)
        .snapshots();
  }

  // New method to create a featured item
  static Future<void> createFeaturedItem(String itemId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // First check if user can add featured item
    if (!await canAddFeaturedItem()) {
      throw Exception('No featured slots available');
    }

    // Add to featured items collection
    await FirebaseFirestore.instance.collection('featuredItems').add({
      'itemId': itemId,
      'userId': userId,
      'startDate': FieldValue.serverTimestamp(),
      'expiryDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: FEATURED_DAYS_LIMIT))),
      'status': 'active',
    });

    // Also update the item document to mark it as featured
    await FirebaseFirestore.instance.collection('items').doc(itemId).update({
      'isFeatured': true,
      'featuredUntil': Timestamp.fromDate(
          DateTime.now().add(Duration(days: FEATURED_DAYS_LIMIT))),
    });
  }

  // New method to decrement featured ads count
  static Future<void> decrementFeaturedAdsCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    // Only decrement if user doesn't have an active plan
    if (!userDoc.data()?['hasActivePlan']) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'featuredItemsUsed': FieldValue.increment(1),
      });
    }
  }
}
