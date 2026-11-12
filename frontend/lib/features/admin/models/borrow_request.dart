class BorrowRequest {
  final int id;
  final int userId;
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
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      purpose: json['purpose'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      status: json['status'] ?? 'pending',
      totalPrice: double.tryParse(json['total_price'].toString()) ?? 0.0,
      totalDeposit: double.tryParse(json['total_deposit'].toString()) ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'pending',
      slipUrl: json['slip_url'],
      fineAmount: double.tryParse(json['fine_amount'].toString()) ?? 0.0,
      finePaid: json['fine_paid'] is int ? json['fine_paid'] : int.tryParse(json['fine_paid'].toString()) ?? 0,
    );
  }
}
