import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../data/admin_borrow_request.dart';
import '../data/api_repository.dart';
import 'delivery_return_screen.dart';

class AdminDeliveryReturnScreen extends StatefulWidget {
  const AdminDeliveryReturnScreen({super.key});

  @override
  State<AdminDeliveryReturnScreen> createState() =>
      _AdminDeliveryReturnScreenState();
}

class _AdminDeliveryReturnScreenState extends State<AdminDeliveryReturnScreen> {
  final ApiRepository _repository = ApiRepository();
  late Future<List<BorrowRequest>> _requests;
  int? _busyRequestId;

  @override
  void initState() {
    super.initState();
    _requests = _repository.getDeliveryRequests();
  }

  void _reload() {
    setState(() {
      _requests = _repository.getDeliveryRequests();
    });
  }

  Future<void> _handover(BorrowRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันส่งมอบอุปกรณ์?'),
        content: Text('คำขอ #${request.id} · ${request.userName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันส่งมอบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyRequestId = request.id);
    try {
      await _repository.processHandover(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกการส่งมอบคำขอ #${request.id} แล้ว')),
      );
      setState(() {
        _requests = _repository.getDeliveryRequests();
      });
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('บันทึกการส่งมอบไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _openReturn(BorrowRequest request) async {
    final returned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliveryReturnScreen(
          requestId: request.id,
          totalDeposit: request.totalDeposit,
        ),
      ),
    );
    if (returned == true && mounted) _reload();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _date(String value) => value.split('T').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ส่งมอบและรับคืนอุปกรณ์'),
        actions: [
          IconButton(
            tooltip: 'โหลดรายการใหม่',
            onPressed: _busyRequestId == null ? _reload : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<BorrowRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'โหลดรายการไม่สำเร็จ: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            );
          }

          final requests = snapshot.data ?? const <BorrowRequest>[];
          if (requests.isEmpty) {
            return const Center(
              child: Text('ไม่มีรายการที่รอส่งมอบหรือรับคืน'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              final readyForHandover = request.status == 'approved';
              final busy = _busyRequestId == request.id;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'คำขอ #${request.id} · ${readyForHandover ? 'รอส่งมอบ' : 'กำลังเช่า'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ผู้เช่า: ${request.userName.isEmpty ? 'ID ${request.userId}' : request.userName}',
                      ),
                      if (request.purpose.isNotEmpty)
                        Text('วัตถุประสงค์: ${request.purpose}'),
                      Text(
                        'ช่วงเช่า: ${_date(request.startDate)} ถึง ${_date(request.endDate)}',
                      ),
                      Text('เงินมัดจำ: ${request.totalDeposit} บาท'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busyRequestId != null
                              ? null
                              : readyForHandover
                              ? () => _handover(request)
                              : () => _openReturn(request),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  readyForHandover
                                      ? 'บันทึกการส่งมอบ'
                                      : 'บันทึกการรับคืน',
                                ),
                        ),
                      ),
                    ],
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
