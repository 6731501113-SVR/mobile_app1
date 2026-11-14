import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../data/admin_borrow_request.dart';
import '../data/api_repository.dart';

class AdminPendingBorrowScreen extends StatefulWidget {
  const AdminPendingBorrowScreen({super.key});

  @override
  State<AdminPendingBorrowScreen> createState() =>
      _AdminPendingBorrowScreenState();
}

class _AdminPendingBorrowScreenState extends State<AdminPendingBorrowScreen> {
  final ApiRepository _repository = ApiRepository();
  late Future<List<BorrowRequest>> _requests;
  final Map<int, Future<List<BorrowRequestItem>>> _requestItems = {};
  int? _busyRequestId;

  @override
  void initState() {
    super.initState();
    _requests = _repository.getPendingBorrowRequests();
  }

  void _reload() {
    setState(() {
      _requestItems.clear();
      _requests = _repository.getPendingBorrowRequests();
    });
  }

  Future<List<BorrowRequestItem>> _itemsFor(BorrowRequest request) =>
      _requestItems.putIfAbsent(
        request.id,
        () => request.items.isNotEmpty
            ? Future.value(request.items)
            : _repository.getBorrowRequestItems(request.id),
      );

  Future<void> _review(BorrowRequest request, {required bool approve}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'อนุมัติคำขอเช่า?' : 'ไม่อนุมัติคำขอเช่า?'),
        content: Text('คำขอ #${request.id} · ${request.userName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'อนุมัติ' : 'ไม่อนุมัติ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyRequestId = request.id);
    try {
      await _repository.reviewBorrowRequest(request.id, approve: approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'อนุมัติคำขอ #${request.id} แล้ว ผู้เช่าส่งสลิปได้'
                : 'ไม่อนุมัติคำขอ #${request.id} แล้ว',
          ),
        ),
      );
      setState(() {
        _requestItems.clear();
        _requests = _repository.getPendingBorrowRequests();
      });
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('ดำเนินการไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
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
        title: const Text('อนุมัติคำขอเช่า'),
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
                      'โหลดคำขอไม่สำเร็จ: ${snapshot.error}',
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
            return const Center(child: Text('ไม่มีคำขอเช่าที่รออนุมัติ'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              final busy = _busyRequestId == request.id;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'คำขอ #${request.id}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ผู้ขอ: ${request.userName.isEmpty ? 'ID ${request.userId}' : request.userName}',
                      ),
                      if (request.purpose.isNotEmpty)
                        Text('วัตถุประสงค์: ${request.purpose}'),
                      Text(
                        'วันที่เช่า: ${_date(request.startDate)} ถึง ${_date(request.endDate)}',
                      ),
                      Text('จำนวนอุปกรณ์: ${request.itemCount} ชิ้น'),
                      FutureBuilder<List<BorrowRequestItem>>(
                        future: _itemsFor(request),
                        builder: (context, itemSnapshot) {
                          if (itemSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('กำลังโหลดรายการอุปกรณ์...'),
                            );
                          }
                          if (itemSnapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'โหลดรายการอุปกรณ์ไม่สำเร็จ: ${itemSnapshot.error}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            );
                          }
                          final items =
                              itemSnapshot.data ?? const <BorrowRequestItem>[];
                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('ไม่พบรายการอุปกรณ์ในคำขอนี้'),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: items
                                  .map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        top: 2,
                                      ),
                                      child: Text(
                                        '• ${item.equipmentName} (${item.assetCode})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ค่าเช่า ${request.totalPrice} บาท · มัดจำ ${request.totalDeposit} บาท',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busyRequestId == null
                                  ? () => _review(request, approve: false)
                                  : null,
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('ไม่อนุมัติ'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busyRequestId == null
                                  ? () => _review(request, approve: true)
                                  : null,
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('อนุมัติ'),
                            ),
                          ),
                        ],
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
