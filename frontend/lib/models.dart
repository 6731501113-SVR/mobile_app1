/// Models follow the ER diagram: users, categories, equipment.

enum UserRole { borrower, admin }

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username; // student id
  final String fullName;
  final UserRole role;
}

enum EquipmentStatus { available, borrowed, maintenance, lost }

class Category {
  const Category({required this.id, required this.name});

  final int id;
  final String name;
}

class Equipment {
  const Equipment({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    this.imageUrl,
    this.dueDate,
  });

  final int id;
  final String assetCode;
  final String name;
  final int categoryId;
  final String categoryName;
  final EquipmentStatus status;
  final String? imageUrl;

  /// Expected return date when currently borrowed (shown as "คืน 2 พ.ย.").
  final DateTime? dueDate;

  /// Only available items can be picked for a new borrow request.
  bool get selectable => status == EquipmentStatus.available;

  /// ใช้ตอนแอดมินเปลี่ยนสถานะอุปกรณ์ (ข้อมูลเป็น final จึงสร้างชุดใหม่แทนการแก้ค่าเดิม)
  Equipment copyWith({EquipmentStatus? status, DateTime? dueDate}) => Equipment(
        id: id,
        assetCode: assetCode,
        name: name,
        categoryId: categoryId,
        categoryName: categoryName,
        status: status ?? this.status,
        imageUrl: imageUrl,
        dueDate: dueDate ?? this.dueDate,
      );
}

const _thaiMonths = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

String thaiShortDate(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]}';
