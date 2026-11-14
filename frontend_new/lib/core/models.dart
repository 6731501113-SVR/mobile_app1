import 'dates.dart';

// Models mirror the backend JSON (snake_case). Each has fromJson/toJson;
// toJson(fromJson(x)) gives back the same map the backend sends.

double _optionalDouble(dynamic value, String field) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid $field value: $value');
}

enum UserRole { borrower, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        username: j['username'] as String,
        fullName: j['full_name'] as String,
        role: j['role'] == 'admin' ? UserRole.admin : UserRole.borrower,
      );

  /// For local caching only. Never use this as a sign-up body: the server
  /// decides the role, the app must not send one.
  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role.name,
      };

  final int id;
  final String username; // student id
  final String fullName;
  final UserRole role;
}

class Category {
  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        name: (j['name'] ?? j['category_name']) as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  final int id;
  final String name;
}

enum EquipmentStatus { available, borrowed, maintenance, lost }

class Equipment {
  const Equipment({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    this.pricePerDay = 0,
    this.deposit = 0,
    this.imageUrl,
    this.dueDate,
  });

  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        id: j['id'] as int,
        assetCode: j['asset_code'] as String,
        name: j['name'] as String,
        categoryId: j['category_id'] as int,
        categoryName: (j['category_name'] ?? j['category'] ?? '') as String,
        imageUrl: j['image_url'] as String?,
        pricePerDay: _optionalDouble(j['price_per_day'], 'price_per_day'),
        deposit: _optionalDouble(j['deposit'], 'deposit'),
        status: EquipmentStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => EquipmentStatus.maintenance,
        ),
        dueDate: j['due_date'] == null ? null : parseDate(j['due_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'asset_code': assetCode,
        'name': name,
        'category_id': categoryId,
        'category_name': categoryName,
        'image_url': imageUrl,
        'price_per_day': pricePerDay,
        'deposit': deposit,
        'status': status.name,
        'due_date': dueDate == null ? null : isoDate(dueDate!),
      };

  final int id;
  final String assetCode;
  final String name;
  final int categoryId;
  final String categoryName;
  final EquipmentStatus status;

  /// Rental price per day and refundable deposit, in baht.
  final double pricePerDay;
  final double deposit;
  final String? imageUrl;

  /// Expected return date when currently rented (shown as "คืน 2 พ.ย.").
  final DateTime? dueDate;

  /// Only available items can be picked for a new rental request.
  bool get selectable => status == EquipmentStatus.available;

  Equipment copyWith({EquipmentStatus? status, DateTime? dueDate}) => Equipment(
        id: id,
        assetCode: assetCode,
        name: name,
        categoryId: categoryId,
        categoryName: categoryName,
        status: status ?? this.status,
        pricePerDay: pricePerDay,
        deposit: deposit,
        imageUrl: imageUrl,
        dueDate: dueDate ?? this.dueDate,
      );
}
