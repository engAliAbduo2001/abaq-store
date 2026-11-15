class Perfume {
  const Perfume({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.description,
    required this.notes,
    required this.price,
    required this.imageUrl,
    this.badge,
    this.rating = 4.5,
    this.isBestseller = false,
    this.isNew = false,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String description;
  final List<String> notes;
  final double price;
  final String imageUrl;
  final String? badge;
  final double rating;
  final bool isBestseller;
  final bool isNew;

  factory Perfume.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Perfume field "$key" is missing or invalid.');
      }
      return value;
    }

    final price = json['price'];
    final rawNotes = json['notes'];
    final badge = json['badge'];
    final rating = json['rating'];
    final isBestseller = json['isBestseller'];
    final isNew = json['isNew'];
    if (price is! num ||
        rawNotes is! List ||
        (badge != null && badge is! String) ||
        (rating != null && rating is! num) ||
        (isBestseller != null && isBestseller is! bool) ||
        (isNew != null && isNew is! bool)) {
      throw const FormatException('Perfume record is invalid.');
    }
    if (rawNotes.any((note) => note is! String)) {
      throw const FormatException('Perfume notes are invalid.');
    }

    return Perfume(
      id: requiredString('id'),
      name: requiredString('name'),
      brand: requiredString('brand'),
      category: requiredString('category'),
      description: requiredString('description'),
      notes: rawNotes.cast<String>(),
      price: price.toDouble(),
      imageUrl: requiredString('imageUrl'),
      badge: badge as String?,
      rating: rating is num ? rating.toDouble() : 4.5,
      isBestseller: isBestseller is bool ? isBestseller : badge == 'BESTSELLER',
      isNew: isNew is bool ? isNew : badge == 'NEW',
    );
  }
}
