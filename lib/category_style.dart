import 'package:flutter/material.dart';

class CategoryStyle {
  const CategoryStyle(this.icon, this.background, this.foreground);

  final IconData icon;
  final Color background;
  final Color foreground;
}

const categoryStyles = <String, CategoryStyle>{
  'Transfers': CategoryStyle(
    Icons.person_rounded,
    Color(0xFF1C2434),
    Colors.white,
  ),
  'Taxi': CategoryStyle(
    Icons.directions_car_filled_rounded,
    Color(0xFF111111),
    Colors.white,
  ),
  'Groceries': CategoryStyle(
    Icons.shopping_cart_rounded,
    Color(0xFFE7F6EE),
    Color(0xFF157A3A),
  ),
  'Food': CategoryStyle(
    Icons.restaurant_rounded,
    Color(0xFFFFF1E6),
    Color(0xFFD35400),
  ),
  'Shopping': CategoryStyle(
    Icons.shopping_bag_rounded,
    Color(0xFFEEEAFE),
    Color(0xFF5B4BDB),
  ),
  'Bills': CategoryStyle(
    Icons.receipt_long_rounded,
    Color(0xFFE7F4F8),
    Color(0xFF0F6E8C),
  ),
  'Income': CategoryStyle(
    Icons.south_west_rounded,
    Color(0xFFE7F8F0),
    Color(0xFF1AAE6F),
  ),
  'Conversion': CategoryStyle(
    Icons.swap_horiz_rounded,
    Color(0xFFE8EEFF),
    Color(0xFF2457D6),
  ),
  'Health': CategoryStyle(
    Icons.favorite_rounded,
    Color(0xFFFFE8EE),
    Color(0xFFD23B67),
  ),
  'Other': CategoryStyle(
    Icons.grid_view_rounded,
    Color(0xFFF1F2F6),
    Color(0xFF3A4154),
  ),
};

CategoryStyle styleFor(String category) {
  return categoryStyles[category] ?? categoryStyles['Other']!;
}

String? initialsFor(String category, String title) {
  if (category != 'Transfers') return null;
  final parts = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) return null;
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
