import 'package:flutter/foundation.dart';

import '../models/borrow_request.dart';
import '../utils/rental_calculator.dart';
import '../utils/slip_utils.dart';

/// รูปสลิปที่ผู้ใช้เลือกมา
class PickedSlip {
  final String name;
  final Uint8List bytes;
  final String? mimeType;

  const PickedSlip({required this.name, required this.bytes, this.mimeType});
}

/// ตัวเลือกรูป แยกเป็นอินเทอร์เฟซเพื่อให้ controller ทดสอบได้โดยไม่ต้องเปิดแกลเลอรีจริง
/// ของจริงอยู่ที่ gallery_slip_picker.dart ส่วนในเทสต์ใช้ของปลอม
abstract class SlipPicker {
  /// คืน null ถ้าผู้ใช้ปิดหน้าเลือกรูปเฉยๆ
  Future<PickedSlip?> pick();
}

/// "สมอง" ของหน้าชำระเงิน: เลือกสลิป ตรวจชนิด/ขนาดไฟล์ ส่งสลิป และนับเวลาที่เหลือ
class PaymentController extends ChangeNotifier {
  PaymentController({
    required this.request,
    required this.picker,
    required this.submitSlip,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final BorrowRequest request;
  final SlipPicker picker;
  final Future<void> Function(PickedSlip slip) submitSlip;
  final DateTime Function() _now;

  String? _slipName;
  Uint8List? _slipBytes;
  String? _mimeType;
  bool _sending = false;

  String? get slipName => _slipName;
  Uint8List? get slipBytes => _slipBytes;
  bool get hasSlip => _slipBytes != null;
  bool get isSending => _sending;

  /// กดส่งสลิปได้เมื่อใบยังจ่ายได้ และเลือกรูปแล้ว
  bool get canSend => request.canPay && hasSlip && !_sending;

  /// เวลาที่เหลือก่อนครบกำหนดชำระ (null ถ้าไม่มีกำหนด หรือจ่ายไม่ได้แล้ว)
  Duration? get timeLeftToPay {
    final due = request.paymentDueAt;
    if (due == null || !request.canPay) return null;
    return timeLeft(due, _now());
  }

  /// ข้อความเวลาที่เหลือ เช่น "5 ชม. 20 นาที" (null ถ้าไม่มีกำหนด)
  String? get timeLeftLabel {
    final left = timeLeftToPay;
    return left == null ? null : timeLeftText(left);
  }

  /// เลือกรูปสลิป คืนข้อความ error ถ้าไฟล์ไม่ผ่าน หรือ null ถ้าผ่าน/ผู้ใช้ยกเลิก
  Future<String?> pickSlip() async {
    try {
      final file = await picker.pick();
      if (file == null) return null;
      final error = slipError(
        file.name,
        file.bytes.length,
        mimeType: file.mimeType,
      );
      if (error != null) return error;
      _slipName = file.name;
      _slipBytes = file.bytes;
      _mimeType = file.mimeType;
      notifyListeners();
      return null;
    } catch (_) {
      return 'เปิดแกลเลอรีไม่ได้ กรุณาลองอีกครั้ง';
    }
  }

  /// ส่งสลิป คืน false ถ้าส่งไม่ได้ (ยังไม่เลือกรูป / ชำระแล้ว / รอตรวจ / หมดเวลา)
  Future<bool> send() async {
    if (!canSend) return false;
    _sending = true;
    notifyListeners();
    try {
      await submitSlip(
        PickedSlip(name: _slipName!, bytes: _slipBytes!, mimeType: _mimeType),
      );
      return true;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// ให้หน้าจอเรียกเป็นระยะเพื่ออัปเดตเวลาที่เหลือ
  void refresh() {
    notifyListeners();
  }
}
