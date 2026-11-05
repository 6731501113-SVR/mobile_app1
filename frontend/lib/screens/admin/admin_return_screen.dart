import 'package:flutter/material.dart';

import '../../mock/app_store.dart';
import '../../models/borrow_request.dart';
import '../../theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/common.dart';

/// A4b: ตรวจรับอุปกรณ์ทีละชิ้น คำนวณค่าปรับ แล้วบันทึกการรับคืน
class AdminReturnScreen extends StatefulWidget {
  final BorrowRequest request;

  const AdminReturnScreen({super.key, required this.request});

  @override
  State<AdminReturnScreen> createState() => _AdminReturnScreenState();
}

class _AdminReturnScreenState extends State<AdminReturnScreen> {
  final AppStore _store = AppStore.instance;
  final TextEditingController _note = TextEditingController();
  final TextEditingController _extra = TextEditingController();
  final DateTime _now = DateTime.now();

  late final List<String> _conditions =
      List<String>.filled(widget.request.items.length, 'good');
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _extra.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _extra.dispose();
    super.dispose();
  }

  BorrowRequest get _r => widget.request;

  int get _lateDays {
    final diff = dateOnly(_now).difference(dateOnly(_r.endDate)).inDays;
    return diff > 0 ? diff : 0;
  }

  bool get _hasProblem => _conditions.any((c) => c != 'good');

  double get _extraFine {
    if (!_hasProblem) return 0;
    final v = double.tryParse(_extra.text.trim()) ?? 0;
    return v < 0 ? 0 : v;
  }

  double get _lateFine => _lateDays * _r.fineRatePerDay;
  double get _totalFine => _lateFine + _extraFine;

  String _two(int n) => n.toString().padLeft(2, '0');

  void _save() {
    _store.returnRequest(
      _r,
      conditions: _conditions,
      extraFine: _extraFine,
      paid: _paid,
      returnedAt: _now,
      note: _note.text,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจรับอุปกรณ์')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          // ข้อมูลผู้ยืม
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_r.borrowerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'กำหนดคืน ${thaiShort(_r.endDate)} · ยืม ${_r.items.length} ชิ้น',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (_lateDays > 0)
                  const StatusBadge(
                    label: 'เกินกำหนด',
                    background: AppColors.redSoft,
                    foreground: AppColors.redText,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ตรวจสภาพทีละชิ้น
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ตรวจสภาพทีละชิ้น',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                for (var i = 0; i < _r.items.length; i++) ...[
                  if (i > 0) const Divider(height: 22, color: AppColors.line),
                  Text(_r.items[i].equipment.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    '${_r.items[i].equipment.assetCode} · ก่อนยืม: ${_r.items[i].conditionBefore}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'good', label: Text('ปกติ')),
                        ButtonSegment(value: 'damaged', label: Text('ชำรุด')),
                        ButtonSegment(value: 'lost', label: Text('สูญหาย')),
                      ],
                      selected: {_conditions[i]},
                      onSelectionChanged: (s) => setState(() => _conditions[i] = s.first),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // วันคืนจริง + หมายเหตุ
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'คืนจริง ${thaiShort(_now)} · ${_two(_now.hour)}:${_two(_now.minute)} น.',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text('หมายเหตุจากผู้ดูแล',
                    style: TextStyle(fontSize: 13, color: AppColors.grayText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'เช่น สายไมค์มีรอยขีดข่วนเล็กน้อย'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ค่าปรับ
          _buildFineCard(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _save,
            child: const Text('บันทึกการรับคืน'),
          ),
        ),
      ),
    );
  }

  Widget _buildFineCard() {
    final total = _totalFine;
    final hasFine = total > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFine ? AppColors.redSoft : AppColors.greenSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lateDays > 0
                ? 'ค่าปรับ: เกิน $_lateDays วัน × ${_r.fineRatePerDay.toStringAsFixed(0)} บาท/วัน'
                : 'คืนตรงเวลา ไม่มีค่าปรับเกินกำหนด',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: hasFine ? AppColors.redText : AppColors.greenText,
            ),
          ),
          if (_hasProblem) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _extra,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'ค่าชดเชยความเสียหาย / สูญหาย (บาท ถ้ามี)',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            baht(total),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: hasFine ? AppColors.redText : AppColors.greenText,
            ),
          ),
          if (hasFine) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('ยังไม่จ่าย')),
                  ButtonSegment(value: true, label: Text('จ่ายแล้ว (เงินสด)')),
                ],
                selected: {_paid},
                onSelectionChanged: (s) => setState(() => _paid = s.first),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
