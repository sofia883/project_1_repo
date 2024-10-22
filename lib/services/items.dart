import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String name;
  final double price;
  final String description;
  final String category;
  final List images;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.images,
    required this.createdAt,
  });

  factory Item.fromMap(String id, Map map) {
    return Item(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      images: List.from(map['images'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}