import 'package:flutter/material.dart';
import '../models/borrow_request.dart';
import '../repositories/api_repository.dart';

class AdminPendingSlipScreen extends StatefulWidget {
  const AdminPendingSlipScreen({super.key});

  @override
  State<AdminPendingSlipScreen> createState() => _AdminPendingSlipScreenState();
}

class _AdminPendingSlipScreenState extends State<AdminPendingSlipScreen> {
  final ApiRepository _apiRepository = ApiRepository();
  late Future<List<BorrowRequest>> _pendingListFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _pendingListFuture = _apiRepository.getPendingSlips();
    });
  }

  void _showSlipDetailModal(BorrowRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ตรวจสอบสลิป (คำขอ # \${request.id})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ผู้ใช้ ID: \${request.userId}'),
              Text('วัตถุประสงค์: \${request.purpose}'),
              Text('ยอดรวม: \${request.totalPrice} บาท | มัดจำ: \${request.totalDeposit} บาท'),
              const SizedBox(height: 12),
              const Text('รูปภาพสลิปโอนเงิน:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 250,
                width: double.infinity,
                color: Colors.grey[200],
                child: request.slipUrl != null && request.slipUrl!.isNotEmpty
                    ? Image.network(
                        request.slipUrl!.startsWith('http')
                            ? request.slipUrl!
                            : '\${ApiRepository.baseUrl}/\${request.slipUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Text('ไม่สามารถโหลดรูปภาพสลิปได้')),
                      )
                    : const Center(child: Text('ไม่มีหลักฐานสลิปโอนเงิน')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _processVerification(request.id, false);
            },
            child: const Text('ปฏิเสธสลิป'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              await _processVerification(request.id, true);
            },
            child: const Text('ยืนยันสลิป (อนุมัติ)'),
          ),
        ],
      ),
    );
  }

  Future<void> _processVerification(int requestId, bool approve) async {
    bool success = await _apiRepository.verifySlip(requestId, approve, approve ? 'สลิปถูกต้อง' : 'สลิปไม่ถูกต้อง');
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'อนุมัติสลิปสำเร็จ' : 'ปฏิเสธสลิปเรียบร้อย')),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แดชบอร์ดตรวจสอบสลิปโอนเงิน')),
      body: FutureBuilder<List<BorrowRequest>>(
        future: _pendingListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: \${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ไม่มีใบคำขอที่รอตรวจสลิปในขณะนี้'));
          }

          final requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('คำขอรหัส: #\${req.id} (User ID: \${req.userId})'),
                  subtitle: Text('ยอดชำระ: \${req.totalPrice + req.totalDeposit} บาท\nวันที่ยืม: \${req.startDate} ถึง \${req.endDate}'),
                  trailing: ElevatedButton(
                    onPressed: () => _showSlipDetailModal(req),
                    child: const Text('ตรวจสลิป'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
