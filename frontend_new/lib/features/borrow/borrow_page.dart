import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/common_widgets.dart';
import '../../core/dates.dart';
import '../../core/equipment_ui.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'borrow_repository.dart';
import 'calendar.dart';

/// Second half of the borrow flow: takes the items picked on the home page,
/// asks for purpose + date range and submits one request per item.
/// Pops with `true` when the request was sent.
class BorrowRequestPage extends StatefulWidget {
  const BorrowRequestPage({
    super.key,
    required this.items,
    required this.borrowRepo,
  });

  final List<Equipment> items;
  final BorrowRepository borrowRepo;

  @override
  State<BorrowRequestPage> createState() => _BorrowRequestPageState();
}

class _BorrowRequestPageState extends State<BorrowRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  late final DateTime _today;

  Set<int> _blocked = {};
  bool _loadingDates = true;
  String? _datesError;

  DateTime? _start;
  DateTime? _end;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _loadBooked();
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _loadBooked() async {
    setState(() {
      _loadingDates = true;
      _datesError = null;
    });
    try {
      final lists = await Future.wait(
        widget.items.map((e) => widget.borrowRepo.fetchBookedRanges(e.id)),
      );
      // A day is blocked if ANY selected item is booked on it, because all
      // items in one request share the same dates.
      final blocked = <int>{};
      for (final ranges in lists) {
        for (final r in ranges) {
          for (var d = r.start;
              !d.isAfter(r.end);
              d = DateTime(d.year, d.month, d.day + 1)) {
            blocked.add(dayKey(d));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _loadingDates = false;
        final s = _start;
        final e = _end;
        if (s != null && e != null && rangeHasBlocked(s, e, blocked)) {
          _start = null;
          _end = null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDates = false;
        _datesError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDates = false;
        _datesError = 'โหลดปฏิทินไม่สำเร็จ';
      });
    }
  }

  void _onTapDate(DateTime d) {
    setState(() {
      _error = null;
      final s = _start;
      if (s == null || _end != null) {
        _start = d; // begin a new selection
        _end = null;
        return;
      }
      if (d.isBefore(s)) {
        _start = d;
        return;
      }
      if (rangeHasBlocked(s, d, _blocked)) {
        _start = d;
        _end = null;
        _error = 'ช่วงที่เลือกมีวันที่ถูกจองแล้ว กรุณาเลือกช่วงอื่น';
        return;
      }
      _end = d;
    });
  }

  String _describeConflicts(ApiException e) {
    final d = e.details;
    if (e.code != 'EQUIPMENT_UNAVAILABLE' || d is! List) return e.message;
    final names = {for (final i in widget.items) i.id: i.name};
    final lines = <String>[];
    for (final c in d) {
      if (c is! Map) continue;
      final name = names[c['equipment_id']] ?? 'อุปกรณ์ #${c['equipment_id']}';
      final why = switch (c['reason']) {
        'DATE_BOOKED' => 'ช่วงวันที่นี้ถูกจองแล้ว',
        'NOT_AVAILABLE' => 'ไม่พร้อมให้เช่า',
        'NOT_FOUND' => 'ไม่พบอุปกรณ์',
        _ => 'ไม่สามารถเช่าได้',
      };
      lines.add('• $name: $why');
    }
    return '${e.message}\n${lines.join('\n')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final s = _start;
    final e = _end;
    if (s == null || e == null) {
      setState(() => _error = 'กรุณาเลือกวันที่เช่าและวันที่คืนในปฏิทิน');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.borrowRepo.create(
        equipmentIds: widget.items.map((i) => i.id).toList(),
        purpose: _purpose.text.trim(),
        start: s,
        end: e,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำขอเช่า ${widget.items.length} ชิ้นแล้ว รอผู้ดูแลอนุมัติ'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (ex) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _describeConflicts(ex);
      });
      if (ex.code == 'EQUIPMENT_UNAVAILABLE') _loadBooked(); // refresh the calendar
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'ส่งคำขอไม่สำเร็จ กรุณาลองอีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SquareIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'กลับ',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ส่งคำขอเช่า',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'อุปกรณ์ ${widget.items.length} ชิ้น',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _itemsCard(),
                    const SizedBox(height: 12),
                    _formCard(),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'คืนเกินกำหนดมีค่าปรับต่อวัน และต้องรอผู้ดูแลอนุมัติก่อนรับของ',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('ส่งคำขอเช่า'),
          ),
        ),
      ),
    );
  }

  Widget _itemsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < widget.items.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.border),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tileAvailable,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIcon(widget.items[i].categoryName),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.items[i].name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${widget.items[i].assetCode} · ${widget.items[i].categoryName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                StatusChip(widget.items[i].status),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: 'วัตถุประสงค์ / ชื่องาน',
              hint: 'เช่น ถ่ายภาพงานปัจฉิมนิเทศ',
              controller: _purpose,
              enabled: !_busy,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'กรุณากรอกวัตถุประสงค์';
                if (s.length > 500) return 'ยาวเกินไป (สูงสุด 500 ตัวอักษร)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'เลือกวันที่เช่า – วันที่คืน',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _calendarArea(),
            const SizedBox(height: 10),
            Row(
              children: const [
                _LegendDot(color: AppColors.primary, label: 'ที่เลือก'),
                SizedBox(width: 16),
                _LegendDot(color: Color(0xFFF6C9C9), label: 'ถูกจองแล้ว (เลือกไม่ได้)'),
              ],
            ),
            if (widget.items.length > 1) ...[
              const SizedBox(height: 6),
              const Text(
                'วันที่ถูกจองของอุปกรณ์ชิ้นใดชิ้นหนึ่ง จะเลือกไม่ได้สำหรับทั้งคำขอ',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            _banner(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBox(_error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calendarArea() {
    if (_loadingDates) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_datesError != null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_datesError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _loadBooked, child: const Text('ลองอีกครั้ง')),
            ],
          ),
        ),
      );
    }
    return RangeCalendar(
      today: _today,
      blocked: _blocked,
      start: _start,
      end: _end,
      onTap: _busy ? (_) {} : _onTapDate,
    );
  }

  Widget _banner() {
    final s = _start;
    final e = _end;
    final ok = s != null && e != null;
    final text = s == null
        ? 'แตะเลือกวันที่เช่า แล้วแตะวันที่คืน'
        : e == null
            ? 'เช่าวันที่ ${thaiShortDate(s)} · แตะเลือกวันที่คืน (แตะวันเดิมซ้ำหากคืนวันเดียวกัน)'
            : 'เลือก ${thaiRangeLabel(s, e)} ว่าง ส่งคำขอได้';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFD8F0DF) : AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_rounded : Icons.info_outline_rounded,
            size: 18,
            color: ok ? const Color(0xFF1E6B3A) : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: ok ? const Color(0xFF1E6B3A) : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
