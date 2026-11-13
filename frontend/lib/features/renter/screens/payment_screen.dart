import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../controllers/gallery_slip_picker.dart';
import '../controllers/payment_controller.dart';
import '../models/borrow_request.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../widgets/common.dart';
import '../mock/app_store.dart' show requestTitle;

/// U7: ชำระเงิน — สรุปยอด (ค่าเช่า + มัดจำ) สแกน QR แล้วแนบสลิป ผู้ดูแลจะตรวจและยืนยัน
///
/// หน้านี้มีหน้าที่แสดงผลเท่านั้น การเลือกสลิป ตรวจไฟล์ ส่งสลิป และนับเวลาที่เหลือ
/// อยู่ใน PaymentController (controllers/payment_controller.dart)
///  - ต้องชำระภายในเวลาที่กำหนดหลังอนุมัติ ไม่งั้นระบบยกเลิกอัตโนมัติ (นับถอยหลังในหน้านี้)
///  - ปุ่มแนบสลิปเปิดแกลเลอรีจริงด้วย image_picker แล้วส่งไฟล์ให้ backend ตรวจสอบ
class PaymentScreen extends StatefulWidget {
  final BorrowRequest request;
  final Future<void> Function(PickedSlip slip) onSubmitSlip;

  const PaymentScreen({
    super.key,
    required this.request,
    required this.onSubmitSlip,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final PaymentController _c;
  Timer? _ticker; // รีเฟรชตัวนับเวลาทุก 30 วินาที

  BorrowRequest get _r => widget.request;

  @override
  void initState() {
    super.initState();
    _c = PaymentController(
      request: widget.request,
      picker: GallerySlipPicker(),
      submitSlip: widget.onSubmitSlip,
    );
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _c.refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickSlip() async {
    final error = await _c.pickSlip();
    if (error != null && mounted) _snack(error);
  }

  Future<void> _submit() async {
    try {
      final sent = await _c.send();
      if (!mounted) return;
      if (!sent) {
        _snack('ส่งสลิปไม่ได้ ใบนี้ชำระแล้ว อยู่ระหว่างตรวจ หรือหมดเวลาชำระ');
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('ส่งสลิปแล้ว รอผู้ดูแลตรวจสอบ')),
      );
    } on ApiException catch (error) {
      if (mounted) _snack(error.message);
    } catch (error) {
      if (mounted) _snack('ส่งสลิปไม่สำเร็จ: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('ชำระเงิน')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              _buildSummary(),
              const SizedBox(height: 12),
              ..._buildStatusNotices(),
              if (_r.canPay) _buildPayBox(),
            ],
          ),
          bottomNavigationBar: _r.canPay
              ? Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: FilledButton(
                      onPressed: _c.canSend ? _submit : null,
                      child: _c.isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('ส่งสลิป ${baht(_r.amountDue)}'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// กล่องแจ้งสถานะด้านบน (หมดเวลา / นับถอยหลัง / สลิปถูกปฏิเสธ / รอตรวจ / จ่ายแล้ว)
  List<Widget> _buildStatusNotices() {
    final out = <Widget>[];
    void add(Widget w) {
      out.add(w);
      out.add(const SizedBox(height: 12));
    }

    if (_r.status == RequestStatus.cancelled) {
      add(Notice(
        background: AppColors.redSoft,
        foreground: AppColors.redText,
        icon: Icons.cancel_outlined,
        text: _r.adminNote ?? 'คำขอนี้ถูกยกเลิกแล้ว',
      ));
      return out;
    }

    if (_r.canPay && _r.paymentDueAt != null) {
      add(Notice(
        background: AppColors.amberSoft,
        foreground: AppColors.amberText,
        icon: Icons.timer_outlined,
        text: 'ชำระภายใน ${_c.timeLeftLabel} '
            '(ก่อน ${thaiShort(_r.paymentDueAt!)} ${hhmm(_r.paymentDueAt!)}) '
            'ไม่เช่นนั้นคำขอจะถูกยกเลิกอัตโนมัติ',
      ));
    }

    if (_r.paymentStatus == PaymentStatus.rejected && _r.paymentNote != null) {
      add(Notice(
        background: AppColors.redSoft,
        foreground: AppColors.redText,
        icon: Icons.info_outline,
        text: 'สลิปครั้งก่อนถูกปฏิเสธ: ${_r.paymentNote} กรุณาส่งใหม่',
      ));
    }
    if (_r.paymentStatus == PaymentStatus.pendingReview) {
      add(const Notice(
        background: AppColors.blueSoft,
        foreground: AppColors.blueText,
        icon: Icons.hourglass_top,
        text: 'ส่งสลิปแล้ว รอผู้ดูแลตรวจสอบ',
      ));
    } else if (_r.paymentStatus == PaymentStatus.paid) {
      add(const Notice(
        background: AppColors.greenSoft,
        foreground: AppColors.greenText,
        icon: Icons.check_circle_outline,
        text: 'ชำระเงินเรียบร้อยแล้ว รอรับอุปกรณ์ตามวันที่จอง',
      ));
    }
    return out;
  }

  Widget _buildSummary() {
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: bold ? 15 : 14,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: bold ? AppColors.text : AppColors.grayText)),
              Text(value,
                  style: TextStyle(
                      fontSize: bold ? 18 : 14,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(requestTitle(_r),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text('เช่า ${thaiShort(_r.startDate)} – ${thaiShort(_r.endDate)} (${_r.days} วัน)',
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 8),
          for (final i in _r.items)
            row('${i.equipment.name} × ${_r.days} วัน', baht(i.pricePerDay * _r.days)),
          const Divider(height: 16),
          row('ค่าเช่า', baht(_r.rentalTotal)),
          row('เงินมัดจำ (คืนเมื่อคืนของสภาพดี)', baht(_r.depositTotal)),
          const Divider(height: 16),
          row('ยอดที่ต้องชำระ', baht(_r.amountDue), bold: true),
        ],
      ),
    );
  }

  Widget _buildPayBox() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สแกน QR เพื่อโอนเงิน',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.graySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              // ช่องนี้แทนรูป QR พร้อมเพย์จริงของชมรม (ยังไม่ได้ใส่ ต้องขอจากชมรม)
              child: const Icon(Icons.qr_code_2, size: 110, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('พร้อมเพย์ของชมรม: [เบอร์/เลขพร้อมเพย์ของชมรม]',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          const SizedBox(height: 14),
          const Text('หลักฐานการโอน',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_c.slipBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.graySoft,
                constraints: const BoxConstraints(maxHeight: 260),
                width: double.infinity,
                child: Image.memory(_c.slipBytes!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: _c.isSending ? null : _pickSlip,
            icon: const Icon(Icons.attach_file),
            label: Text(_c.slipName == null
                ? 'แนบสลิปการโอน'
                : 'แนบแล้ว: ${_c.slipName} (แตะเพื่อเปลี่ยน)'),
          ),
          const SizedBox(height: 6),
          const Text(
            'รับไฟล์ JPG หรือ PNG ไม่เกิน 5 MB · ผู้ดูแลจะตรวจยอดและยืนยัน ได้รับอุปกรณ์หลังยืนยันแล้วเท่านั้น',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
