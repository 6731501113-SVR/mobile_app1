import 'package:flutter/material.dart';

import '../mock/app_store.dart';
import '../models/borrow_request.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../widgets/common.dart';
import 'fine_screen.dart';

/// U5: รายการยืมของฉัน — กรองตามสถานะ ยกเลิกคำขอ และไปหน้าค่าปรับ
class MyLoansScreen extends StatefulWidget {
  final String borrowerId; // รหัสผู้ใช้ที่ login อยู่ (username)

  const MyLoansScreen({super.key, required this.borrowerId});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  static const _filters = ['ทั้งหมด', 'รออนุมัติ', 'กำลังยืม', 'ประวัติ'];
  String _filter = 'ทั้งหมด';

  final AppStore _store = AppStore.instance;

  List<BorrowRequest> get _mine => _store.requestsOf(widget.borrowerId);

  List<BorrowRequest> get _filtered {
    final mine = _mine;
    switch (_filter) {
      case 'รออนุมัติ':
        return mine.where((r) => r.status == RequestStatus.pending).toList();
      case 'กำลังยืม':
        return mine
            .where((r) => r.status == RequestStatus.approved || r.status == RequestStatus.borrowed)
            .toList();
      case 'ประวัติ':
        return mine
            .where((r) =>
                r.status == RequestStatus.returned ||
                r.status == RequestStatus.rejected ||
                r.status == RequestStatus.cancelled)
            .toList();
      default:
        return List.of(mine);
    }
  }

  void _cancel(BorrowRequest r) {
    // เปลี่ยนเป็น cancelled (ไม่ลบทิ้ง ประวัติจะได้ไม่หาย)
    _store.cancel(r);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ยกเลิกคำขอแล้ว')),
    );
  }

  void _openFine(BorrowRequest r) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FineScreen(request: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('รายการยืมของฉัน')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppColors.teal,
                      labelStyle: TextStyle(
                        color: _filter == f ? Colors.white : AppColors.text,
                        fontWeight: _filter == f ? FontWeight.w600 : FontWeight.w500,
                      ),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('ยังไม่มีรายการยืม', style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _buildCard(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BorrowRequest r) {
    final first = r.items.first.equipment.name;
    final title = r.items.length > 1 ? '$first + อีก ${r.items.length - 1} ชิ้น' : first;
    final hasUnpaidFine = r.fineStatus == FineStatus.unpaid && r.totalFine > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(r.purpose, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              requestStatusBadge(r),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ช่วงยืม: ${thaiShort(r.startDate)} – ${thaiShort(r.endDate)}',
            style: const TextStyle(fontSize: 13, color: AppColors.grayText),
          ),
          if (r.isOverdue)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'เกินกำหนดคืนมาแล้ว ${r.lateDays} วัน',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.redText),
              ),
            ),
          if (r.status == RequestStatus.rejected && r.adminNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Notice(
                background: AppColors.redSoft,
                foreground: AppColors.redText,
                icon: Icons.info_outline,
                text: 'เหตุผล: ${r.adminNote}',
              ),
            ),
          if (r.fineStatus == FineStatus.paid)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  label: 'จ่ายค่าปรับแล้ว',
                  background: AppColors.greenSoft,
                  foreground: AppColors.greenText,
                ),
              ),
            ),
          if (hasUnpaidFine) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: 'ค่าปรับ ${baht(r.totalFine)} · ยังไม่จ่าย',
                background: AppColors.redSoft,
                foreground: AppColors.redText,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => _openFine(r),
              child: const Text('ดูวิธีชำระค่าปรับ'),
            ),
          ],
          if (r.status == RequestStatus.pending) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              onPressed: () => _cancel(r),
              child: const Text('ยกเลิกคำขอ'),
            ),
          ],
        ],
      ),
    );
  }
}
