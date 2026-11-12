import 'package:flutter/material.dart';
import '../repositories/api_repository.dart';

class DeliveryReturnScreen extends StatefulWidget {
  final int requestId;
  final double totalDeposit;

  const DeliveryReturnScreen({super.key, required this.requestId, required this.totalDeposit});

  @override
  State<DeliveryReturnScreen> createState() => _DeliveryReturnScreenState();
}

class _DeliveryReturnScreenState extends State<DeliveryReturnScreen> {
  final ApiRepository _apiRepository = ApiRepository();
  final TextEditingController _fineController = TextEditingController(text: '0.0');
  String _conditionAfter = 'good';
  bool _isLoading = false;

  void _submitReturn() async {
    double fine = double.tryParse(_fineController.text) ?? 0.0;
    setState(() => _isLoading = true);

    try {
      bool success = await _apiRepository.processReturn(widget.requestId, fine, _conditionAfter);
      if (success) {
        double refundAmount = widget.totalDeposit - fine;
        if (refundAmount < 0) refundAmount = 0;

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('บันทึกการรับคืนสำเร็จ'),
            content: Text('หักค่าปรับ: \$fine บาท\nยอดเงินมัดจำที่ต้องคืนผู้ยืม: \$refundAmount บาท'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // ปิด Dialog
                  Navigator.pop(context, true); // กลับหน้าก่อนหน้า
                },
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกไม่สำเร็จ')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double fine = double.tryParse(_fineController.text) ?? 0.0;
    double calculatedRefund = widget.totalDeposit - fine;
    if (calculatedRefund < 0) calculatedRefund = 0;

    return Scaffold(
      appBar: AppBar(title: const Text('จัดการส่งมอบและรับคืนอุปกรณ์')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('รหัสคำขอยืม: #\${widget.requestId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('เงินมัดจำทั้งหมด: \${widget.totalDeposit} บาท', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _conditionAfter,
              decoration: const InputDecoration(labelText: 'สภาพอุปกรณ์หลังคืน'),
              items: const [
                DropdownMenuItem(value: 'good', child: Text('ปกติ (Good)')),
                DropdownMenuItem(value: 'damaged', child: Text('ชำรุด (Damaged)')),
                DropdownMenuItem(value: 'lost', child: Text('สูญหาย (Lost)')),
              ],
              onChanged: (val) => setState(() => _conditionAfter = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fineController,
              decoration: const InputDecoration(labelText: 'จำนวนเงินค่าปรับ (บาท)'),
              keyboardType: TextInputType.number,
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สรุปยอดเงินมัดจำ: \${widget.totalDeposit} บาท'),
                  Text('หักค่าปรับ: \$fine บาท'),
                  const Divider(),
                  Text('ยอดเงินมัดจำที่ต้องคืนสุทธิ: \$calculatedRefund บาท',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: _isLoading ? null : _submitReturn,
              child: _isLoading ? const CircularProgressIndicator() : const Text('ยืนยันรับคืนและคำนวณเงินมัดจำ'),
            ),
          ],
        ),
      ),
    );
  }
}
