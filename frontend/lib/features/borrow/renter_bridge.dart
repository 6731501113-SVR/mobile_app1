import '../../core/models.dart' as core;
import '../renter/models/borrow_request.dart' as rn;
import 'borrow_models.dart';

/// Converts the API request (single item, Editor 1) into the richer shape the
/// payment / fine screens (Editor 3) expect. Missing optional backend fields
/// default to 0 / unpaid, so a fine with no deposit is shown as "pay in full".
rn.BorrowRequest toRenterRequest(BorrowRequest r) {
  final item = rn.BorrowItem(
    equipment: core.Equipment(
      id: r.equipmentId,
      assetCode: r.assetCode,
      name: r.equipmentName,
      categoryId: 0,
      categoryName: '',
      status: core.EquipmentStatus.borrowed,
      pricePerDay: r.pricePerDay,
      deposit: r.deposit,
    ),
    conditionAfter: r.conditionAfter,
    // Editor 3 keeps the whole fine on the first item.
    fineAmount: r.fineAmount,
    pricePerDay: r.pricePerDay,
    deposit: r.deposit,
  );

  final rn.RequestStatus status = switch (r.status) {
    RequestStatus.pending => rn.RequestStatus.pending,
    RequestStatus.approved => rn.RequestStatus.approved,
    RequestStatus.borrowing || RequestStatus.overdue => rn.RequestStatus.borrowed,
    RequestStatus.returned => rn.RequestStatus.returned,
    RequestStatus.rejected => rn.RequestStatus.rejected,
    RequestStatus.cancelled => rn.RequestStatus.cancelled,
  };

  final rn.PaymentStatus payment = switch (r.paymentStatus) {
    'pending_review' => rn.PaymentStatus.pendingReview,
    'paid' => rn.PaymentStatus.paid,
    'rejected' => rn.PaymentStatus.rejected,
    _ => rn.PaymentStatus.unpaid,
  };

  return rn.BorrowRequest(
    id: r.id,
    purpose: r.purpose,
    startDate: r.startDate,
    endDate: r.endDate,
    actualReturnDate: r.actualReturnDate,
    status: status,
    fineStatus: !r.hasFine
        ? rn.FineStatus.none
        : (r.finePaid ? rn.FineStatus.paid : rn.FineStatus.unpaid),
    fineRatePerDay: r.finePerDay,
    adminNote: r.adminNote,
    items: [item],
    paymentStatus: payment,
    paymentNote: r.paymentNote,
    paymentDueAt: r.paymentDueAt,
  );
}
