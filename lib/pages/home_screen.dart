import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewItemsScreen extends StatelessWidget {
  const ViewItemsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Items'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No items found.'));
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final images = List<String>.from(item['images'] ?? []);

              return Card(
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'No name',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Price: ${item['price'].toString()}'),
                      SizedBox(height: 8),
                      Text('Category: ${item['category'] ?? 'No category'}'),
                      SizedBox(height: 8),
                      Text(
                          'Description: ${item['description'] ?? 'No description'}'),
                      SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (context, imgIndex) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Image.network(images[imgIndex]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
