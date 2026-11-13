import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/borrow_request.dart';
import '../repositories/api_repository.dart';

class DeliveryReturnScreen extends StatefulWidget {
  final int requestId;
  final double totalDeposit;

  const DeliveryReturnScreen({
    super.key,
    required this.requestId,
    required this.totalDeposit,
  });

  @override
  State<DeliveryReturnScreen> createState() => _DeliveryReturnScreenState();
}

class _DeliveryReturnScreenState extends State<DeliveryReturnScreen> {
  final ApiRepository _apiRepository = ApiRepository();
  late Future<List<BorrowRequestItem>> _items;
  final Map<int, String> _conditions = {};
  final Map<int, TextEditingController> _damageFineControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _items = _apiRepository.getBorrowRequestItems(widget.requestId);
  }

  @override
  void dispose() {
    for (final controller in _damageFineControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _fineControllerFor(BorrowRequestItem item) =>
      _damageFineControllers.putIfAbsent(
        item.equipmentId,
        () => TextEditingController(text: '0'),
      );

  double _damageFineTotal(List<BorrowRequestItem> items) => items.fold<double>(
    0,
    (total, item) =>
        total + (double.tryParse(_fineControllerFor(item).text) ?? 0),
  );

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    throw const FormatException('Invalid amount in return response');
  }

  Future<void> _submitReturn(List<BorrowRequestItem> items) async {
    final damageFines = <Map<String, dynamic>>[];
    for (final item in items) {
      final damageFine = double.tryParse(_fineControllerFor(item).text);
      if (damageFine == null || damageFine < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณากรอกค่าปรับเป็นตัวเลขตั้งแต่ 0 ขึ้นไป'),
          ),
        );
        return;
      }
      damageFines.add({
        'equipment_id': item.equipmentId,
        'condition_after': _conditions[item.equipmentId] ?? 'good',
        'damage_fine': damageFine,
      });
    }

    setState(() => _isLoading = true);
    try {
      final result = await _apiRepository.processReturn(
        widget.requestId,
        damageFines,
      );
      final lateFine = _amount(result['late_fine']);
      final damageFine = _amount(result['total_damage_fine']);
      final totalFine = _amount(result['fine_amount']);
      final refund = widget.totalDeposit > totalFine
          ? widget.totalDeposit - totalFine
          : 0.0;
      final extraDue = totalFine > widget.totalDeposit
          ? totalFine - widget.totalDeposit
          : 0.0;

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('บันทึกการรับคืนสำเร็จ'),
          content: Text(
            'ค่าปรับคืนล่าช้า: $lateFine บาท\n'
            'ค่าปรับความเสียหาย: $damageFine บาท\n'
            'ค่าปรับรวม: $totalFine บาท\n'
            'ยอดเงินมัดจำที่ต้องคืน: $refund บาท\n'
            'ค่าปรับส่วนเกินมัดจำ: $extraDue บาท',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('บันทึกการรับคืนไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการรับคืนอุปกรณ์')),
      body: FutureBuilder<List<BorrowRequestItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'โหลดรายการอุปกรณ์ไม่สำเร็จ: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final items = snapshot.data ?? const <BorrowRequestItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่พบอุปกรณ์ในคำขอนี้'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'รหัสคำขอยืม: #${widget.requestId}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('เงินมัดจำทั้งหมด: ${widget.totalDeposit} บาท'),
              const SizedBox(height: 12),
              for (final item in items) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.equipmentName} · ${item.assetCode}'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _conditions[item.equipmentId] ?? 'good',
                          decoration: const InputDecoration(
                            labelText: 'สภาพอุปกรณ์หลังคืน',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'good',
                              child: Text('ปกติ'),
                            ),
                            DropdownMenuItem(
                              value: 'damaged',
                              child: Text('ชำรุด'),
                            ),
                            DropdownMenuItem(
                              value: 'lost',
                              child: Text('สูญหาย'),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _conditions[item.equipmentId] = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fineControllerFor(item),
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'ค่าปรับความเสียหายของชิ้นนี้ (บาท)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text('ค่าปรับความเสียหายที่ระบุ: ${_damageFineTotal(items)} บาท'),
              const Text(
                'ระบบจะคำนวณค่าปรับคืนล่าช้าให้โดยอัตโนมัติ และสรุปยอดมัดจำหลังบันทึก',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : () => _submitReturn(items),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ยืนยันรับคืนและคำนวณเงินมัดจำ'),
              ),
            ],
          );
        },
      ),
    );
  }
}
