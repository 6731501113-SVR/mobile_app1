import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/common_widgets.dart';
import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../payment/fine_screen.dart';
import '../payment/payment_screen.dart';
import '../payment/request_adapter.dart';
import 'borrow_models.dart';
import 'borrow_repository.dart';
import 'request_widgets.dart';

const _conditionLabels = {
  'normal': 'ปกติ',
  'damaged': 'ชำรุด',
  'lost': 'สูญหาย',
};

// ---------------------------------------------------------------------------
// "รายการของฉัน" tab
// ---------------------------------------------------------------------------

class MyRequestsView extends StatefulWidget {
  const MyRequestsView({super.key, required this.user, required this.repo});

  final AppUser user;
  final BorrowRepository repo;

  @override
  State<MyRequestsView> createState() => _MyRequestsViewState();
}

class _MyRequestsViewState extends State<MyRequestsView> {
  static const _tabs = [
    ('all', 'ทั้งหมด'),
    ('pending', 'รออนุมัติ'),
    ('borrowing', 'กำลังเช่า'),
    ('history', 'ประวัติ'),
  ];

  String _tab = 'all';
  List<BorrowRequest> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool spinner = true}) async {
    final tab = _tab;
    if (spinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await widget.repo.fetchMine(tab: tab);
      if (!mounted || tab != _tab) return; // ignore stale responses
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || tab != _tab) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted || tab != _tab) return;
      setState(() {
        _loading = false;
        _error = 'โหลดรายการเช่าไม่สำเร็จ';
      });
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _cancel(BorrowRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยกเลิกคำขอนี้?'),
        content: Text('${r.equipmentName} (${r.assetCode})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ไม่ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ยกเลิกคำขอ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.cancel(r.id);
      if (!mounted) return;
      _snack('ยกเลิกคำขอแล้ว');
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    }
    if (mounted) _load(spinner: false);
  }

  Future<void> _openFine(BorrowRequest r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FineScreen(request: toRenterRequest(r)),
      ),
    );
    if (mounted) {
      _load(spinner: false); // admin may have marked it paid meanwhile
    }
  }

  Future<void> _openPayment(BorrowRequest r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          request: toRenterRequest(r),
          onSubmitSlip: (slip) => widget.repo.uploadSlip(
            requestId: r.id,
            fileName: slip.name,
            bytes: slip.bytes,
            mimeType: slip.mimeType,
          ),
        ),
      ),
    );
    if (mounted) _load(spinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'รายการเช่าของฉัน',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final (value, label) in _tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _tab == value,
                    showCheckmark: false,
                    onSelected: (_) {
                      if (_tab == value) return;
                      setState(() => _tab = value);
                      _load();
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _tab == value ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(spinner: false),
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'ยังไม่มีรายการเช่า',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _RequestCard(
                request: _items[i],
                onCancel: () => _cancel(_items[i]),
                onFine: () => _openFine(_items[i]),
                onPay: () => _openPayment(_items[i]),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onCancel,
    required this.onFine,
    required this.onPay,
  });

  final BorrowRequest request;
  final VoidCallback onCancel;
  final VoidCallback onFine;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.equipmentName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.assetCode} · ${r.purpose}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RequestStatusChip(r.status),
            ],
          ),
          const SizedBox(height: 12),
          ..._details(),
        ],
      ),
    );
  }

  Widget _dateLine(String text, {Color color = AppColors.textMuted}) => Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color))),
        ],
      );

  List<Widget> _details() {
    final r = request;
    switch (r.status) {
      case RequestStatus.pending:
        return [
          Row(
            children: [
              Expanded(child: Text(thaiDateSpan(r.startDate, r.endDate),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted))),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('ยกเลิกคำขอ'),
              ),
            ],
          ),
          if (r.awaitingPayment) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('ชำระเงิน'),
            ),
          ],
        ];

      case RequestStatus.approved:
        return [
          _dateLine('วันที่เช่า ${thaiDateSpan(r.startDate, r.endDate)}'),
          if (r.awaitingPayment) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('ชำระเงิน'),
            ),
          ] else if (r.paymentStatus == 'pending_review') ...[
            const SizedBox(height: 6),
            const Text(
              'ส่งหลักฐานการชำระเงินแล้ว รอผู้ดูแลตรวจสอบ',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ] else if (r.paymentStatus == 'paid') ...[
            const SizedBox(height: 6),
            const Text(
              'ชำระเงินแล้ว รอรับอุปกรณ์ตามวันที่จอง',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ];

      case RequestStatus.borrowing:
        final left = r.daysLeft;
        final suffix = left == null
            ? ''
            : left == 0
                ? ' (ครบกำหนดวันนี้)'
                : ' (เหลือ $left วัน)';
        return [_dateLine('กำหนดคืน ${thaiShortDate(r.endDate)}$suffix')];

      case RequestStatus.overdue:
        return [
          _dateLine('กำหนดคืน ${thaiShortDate(r.endDate)}'),
          const SizedBox(height: 6),
          Text(
            'เกินกำหนด ${r.lateDays} วัน · ค่าปรับโดยประมาณ ${baht(r.estimatedFine)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
        ];

      case RequestStatus.returned:
        return [
          Row(
            children: [
              Expanded(child: Text(thaiDateSpan(r.startDate, r.endDate),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted))),
              if (!r.hasFine)
                Text(
                  'สภาพหลังคืน: ${_conditionLabels[r.conditionAfter] ?? '-'}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.finePaid ? const Color(0xFFD8F0DF) : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ค่าปรับ ${baht(r.fineAmount)} · ${r.finePaid ? 'จ่ายแล้ว' : 'ยังไม่จ่าย'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: r.finePaid ? const Color(0xFF1E6B3A) : AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          if (r.hasUnpaidFine) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onFine,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('ดูค่าปรับและมัดจำ'),
            ),
          ],
        ];

      case RequestStatus.rejected:
        return [
          Text(thaiDateSpan(r.startDate, r.endDate),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          if (r.adminNote != null && r.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('เหตุผล: ${r.adminNote}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ],
        ];

      case RequestStatus.cancelled:
        return [
          Text(thaiDateSpan(r.startDate, r.endDate),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ];
    }
  }
}
