import '../../core/dates.dart';

/// Inclusive date range (e.g. an already booked period).
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// Matches the backend's `display_status`.
enum RequestStatus { pending, approved, borrowing, overdue, returned, rejected, cancelled }

class BorrowRequest {
  const BorrowRequest({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.assetCode,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.lateDays,
    required this.fineAmount,
    required this.finePaid,
    required this.estimatedFine,
    required this.finePerDay,
    this.actualReturnDate,
    this.daysLeft,
    this.conditionAfter,
    this.adminNote,
    this.pricePerDay = 0,
    this.deposit = 0,
    this.paymentStatus,
    this.paymentDueAt,
    this.paymentNote,
  });

  factory BorrowRequest.fromJson(Map<String, dynamic> j) => BorrowRequest(
        id: j['id'] as int,
        equipmentId: j['equipment_id'] as int,
        equipmentName: j['equipment_name'] as String,
        assetCode: j['asset_code'] as String,
        purpose: j['purpose'] as String,
        startDate: parseDate(j['start_date'] as String),
        endDate: parseDate(j['end_date'] as String),
        actualReturnDate: j['actual_return_date'] == null
            ? null
            : parseDate(j['actual_return_date'] as String),
        status: RequestStatus.values.firstWhere(
          (s) => s.name == j['display_status'],
          orElse: () => RequestStatus.pending,
        ),
        lateDays: j['late_days'] as int,
        daysLeft: j['days_left'] as int?,
        fineAmount: (j['fine_amount'] as num).toDouble(),
        finePaid: j['fine_paid'] as bool,
        estimatedFine: (j['estimated_fine'] as num).toDouble(),
        finePerDay: (j['fine_per_day'] as num).toDouble(),
        conditionAfter: j['condition_after'] as String?,
        adminNote: j['admin_note'] as String?,
        // Optional (payment flow, Editor 3). Missing => defaults.
        pricePerDay: (j['price_per_day'] as num?)?.toDouble() ?? 0,
        deposit: (j['deposit'] as num?)?.toDouble() ?? 0,
        paymentStatus: j['payment_status'] as String?,
        paymentDueAt: j['payment_due_at'] == null
            ? null
            : DateTime.parse(j['payment_due_at'] as String).toLocal(),
        paymentNote: j['payment_note'] as String?,
      );

  final int id;
  final int equipmentId;
  final String equipmentName;
  final String assetCode;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? actualReturnDate;
  final RequestStatus status;
  final int lateDays;
  final int? daysLeft;
  final double fineAmount;
  final bool finePaid;
  final double estimatedFine;
  final double finePerDay;
  final String? conditionAfter;
  final String? adminNote;

  /// Optional payment-flow fields. paymentStatus: unpaid | pending_review |
  /// paid | rejected (null when the backend does not use payments).
  final double pricePerDay;
  final double deposit;
  final String? paymentStatus;
  final DateTime? paymentDueAt;
  final String? paymentNote;

  /// Approved by admin and waiting for the renter to pay (show "ชำระเงิน").
  bool get awaitingPayment =>
      status == RequestStatus.approved &&
      paymentDueAt != null &&
      (paymentStatus == 'unpaid' || paymentStatus == 'rejected');

  bool get hasFine => status == RequestStatus.returned && fineAmount > 0;
  bool get hasUnpaidFine => hasFine && !finePaid;
}
