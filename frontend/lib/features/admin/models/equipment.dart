class Equipment {
  final int? id;
  final String assetCode;
  final String name;
  final int categoryId;
  final String categoryName;
  final String status;
  final String? imageUrl;
  final double pricePerDay;
  final double deposit;
  final int stock;

  Equipment({
    this.id,
    required this.assetCode,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    this.imageUrl,
    required this.pricePerDay,
    required this.deposit,
    required this.stock,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      assetCode: json['asset_code'] ?? '',
      name: json['name'] ?? '',
      categoryId: json['category_id'] is int ? json['category_id'] : int.tryParse(json['category_id'].toString()) ?? 1,
      categoryName: json['category_name'] ?? json['category'] ?? 'ทั่วไป',
      status: json['status'] ?? 'available',
      imageUrl: json['image_url'],
      pricePerDay: double.tryParse(json['price_per_day'].toString()) ?? 0.0,
      deposit: double.tryParse(json['deposit'].toString()) ?? 0.0,
      stock: json['stock'] is int ? json['stock'] : int.tryParse(json['stock'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'asset_code': assetCode,
      'name': name,
      'category_id': categoryId,
      'category_name': categoryName,
      'status': status,
      'image_url': imageUrl,
      'price_per_day': pricePerDay,
      'deposit': deposit,
      'stock': stock,
    };
  }
}
