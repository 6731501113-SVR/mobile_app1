class BorrowRequest {
  final int id;
  final int userId;
  final String userName;
  final int itemCount;
  final List<BorrowRequestItem> items;
  final String purpose;
  final String startDate;
  final String endDate;
  final String status;
  final double totalPrice;
  final double totalDeposit;
  final String paymentStatus;
  final String? slipUrl;
  final double fineAmount;
  final int finePaid;

  BorrowRequest({
    required this.id,
    required this.userId,
    this.userName = '',
    this.itemCount = 1,
    this.items = const [],
    required this.purpose,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
    required this.totalDeposit,
    required this.paymentStatus,
    this.slipUrl,
    required this.fineAmount,
    required this.finePaid,
  });

  factory BorrowRequest.fromJson(Map<String, dynamic> json) {
    return BorrowRequest(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int
          ? json['user_id']
          : int.parse(json['user_id'].toString()),
      userName: json['user_name'] as String? ?? '',
      itemCount: json['item_count'] is int
          ? json['item_count'] as int
          : int.tryParse('${json['item_count']}') ?? 1,
      items: _parseBorrowRequestItems(json['items']),
      purpose: json['purpose'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      status: json['status'] ?? 'pending',
      totalPrice: double.tryParse(json['total_price'].toString()) ?? 0.0,
      totalDeposit: double.tryParse(json['total_deposit'].toString()) ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'pending',
      slipUrl: json['slip_url'],
      fineAmount: double.tryParse(json['fine_amount'].toString()) ?? 0.0,
      finePaid: json['fine_paid'] is int
          ? json['fine_paid']
          : int.tryParse(json['fine_paid'].toString()) ?? 0,
    );
  }
}

List<BorrowRequestItem> _parseBorrowRequestItems(dynamic value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Invalid borrow request items');
  }
  return value.map((item) {
    if (item is! Map) {
      throw const FormatException('Invalid borrow request item');
    }
    return BorrowRequestItem.fromJson(Map<String, dynamic>.from(item));
  }).toList();
}

class BorrowRequestItem {
  const BorrowRequestItem({
    required this.equipmentId,
    required this.equipmentName,
    required this.assetCode,
  });

  final int equipmentId;
  final String equipmentName;
  final String assetCode;

  factory BorrowRequestItem.fromJson(Map<String, dynamic> json) =>
      BorrowRequestItem(
        equipmentId: json['equipment_id'] is int
            ? json['equipment_id'] as int
            : int.parse(json['equipment_id'].toString()),
        equipmentName: json['equipment_name'] as String? ?? '',
        assetCode: json['asset_code'] as String? ?? '',
      );
}
