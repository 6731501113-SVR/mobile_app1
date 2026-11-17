import 'dart:async';
import 'dart:typed_data';

import 'package:frontend/core/models.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';
import 'package:frontend/features/home/equipment_repository.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class FakeAuthRepository implements AuthRepository {
  AppUser user = const AppUser(
    id: 1,
    username: '6731501087',
    fullName: 'สมชาย ใจดี',
    role: UserRole.borrower,
  );

  /// When set, login/register throw it.
  Object? error;

  /// When set, login/register wait for it (to observe the "busy" state).
  Completer<void>? gate;

  final loginCalls = <({String username, String password})>[];
  final registerCalls =
      <({String username, String fullName, String password})>[];

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    loginCalls.add((username: username, password: password));
    await gate?.future;
    if (error != null) throw error!;
    return user;
  }

  @override
  Future<AppUser> register({
    required String username,
    required String fullName,
    required String password,
  }) async {
    registerCalls.add((
      username: username,
      fullName: fullName,
      password: password,
    ));
    await gate?.future;
    if (error != null) throw error!;
    return user;
  }

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<void> logout() async {}
}

class FakeEquipmentRepository implements EquipmentRepository {
  FakeEquipmentRepository({
    List<Equipment>? equipment,
    List<Category>? categories,
  }) : equipment = equipment ?? [],
       categories = categories ?? [];

  List<Equipment> equipment;
  List<Category> categories;

  /// When set, fetches throw it.
  Object? error;

  Completer<void>? gate;
  int fetchCalls = 0;

  @override
  Future<List<Equipment>> fetchEquipment() async {
    fetchCalls++;
    await gate?.future;
    if (error != null) throw error!;
    return equipment;
  }

  @override
  Future<List<Category>> fetchCategories() async => categories;
}

class FakeBorrowRepository implements BorrowRepository {
  FakeBorrowRepository({
    List<BorrowRequest> requests = const [],
    Map<int, List<DateRange>> bookedRanges = const {},
  }) : requests = List.of(requests),
       bookedRanges = Map.of(bookedRanges);

  final List<BorrowRequest> requests;
  final Map<int, List<DateRange>> bookedRanges;
  final requestedTabs = <String>[];
  final fetchedEquipmentIds = <int>[];
  final cancelledIds = <int>[];
  final uploadedSlipIds = <int>[];
  final createdRequests =
      <
        ({List<int> equipmentIds, String purpose, DateTime start, DateTime end})
      >[];

  Object? fetchError;
  Object? createError;
  Completer<void>? fetchGate;
  Completer<void>? createGate;

  @override
  Future<List<BorrowRequest>> create({
    required List<int> equipmentIds,
    required String purpose,
    required DateTime start,
    required DateTime end,
  }) async {
    createdRequests.add((
      equipmentIds: List.of(equipmentIds),
      purpose: purpose,
      start: start,
      end: end,
    ));
    await createGate?.future;
    if (createError != null) throw createError!;
    return const [];
  }

  @override
  Future<List<BorrowRequest>> fetchMine({String tab = 'all'}) async {
    requestedTabs.add(tab);
    await fetchGate?.future;
    if (fetchError != null) throw fetchError!;
    return requests
        .where(
          (request) => switch (tab) {
            'pending' =>
              request.status == RequestStatus.pending ||
                  request.status == RequestStatus.approved,
            'borrowing' =>
              request.status == RequestStatus.borrowing ||
                  request.status == RequestStatus.overdue,
            'history' =>
              request.status == RequestStatus.returned ||
                  request.status == RequestStatus.rejected ||
                  request.status == RequestStatus.cancelled,
            _ => true,
          },
        )
        .toList();
  }

  @override
  Future<List<DateRange>> fetchBookedRanges(int equipmentId) async {
    fetchedEquipmentIds.add(equipmentId);
    await fetchGate?.future;
    if (fetchError != null) throw fetchError!;
    return bookedRanges[equipmentId] ?? const [];
  }

  @override
  Future<BorrowRequest> fetchOne(int id) async => _request(id);

  @override
  Future<BorrowRequest> cancel(int id) async {
    cancelledIds.add(id);
    return _request(id);
  }

  BorrowRequest _request(int id) {
    return requests.firstWhere(
      (request) => request.id == id,
      orElse: () => throw StateError('No mock borrow request with id $id'),
    );
  }

  @override
  Future<void> uploadSlip({
    required int requestId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    uploadedSlipIds.add(requestId);
  }
}

class SampleEquipmentData {
  static const categories = [
    Category(id: 1, name: 'กล้อง'),
    Category(id: 2, name: 'เครื่องเสียง'),
    Category(id: 3, name: 'วิทยุสื่อสาร'),
  ];

  static const equipment = [
    Equipment(
      id: 1,
      name: 'กล้อง Canon EOS M50',
      categoryId: 1,
      categoryName: 'กล้อง',
      assetCode: 'CAM-001',
      status: EquipmentStatus.available,
      pricePerDay: 300,
      deposit: 2000,
    ),
    Equipment(
      id: 2,
      name: 'กล้อง Sony ZV-E10',
      categoryId: 1,
      categoryName: 'กล้อง',
      assetCode: 'CAM-002',
      status: EquipmentStatus.available,
      pricePerDay: 300,
      deposit: 2000,
    ),
    Equipment(
      id: 3,
      name: 'ขาตั้งกล้อง',
      categoryId: 1,
      categoryName: 'กล้อง',
      assetCode: 'TRI-001',
      status: EquipmentStatus.available,
      pricePerDay: 300,
      deposit: 2000,
    ),
    Equipment(
      id: 4,
      name: 'ไมค์ไร้สาย (ชุด 2 ตัว)',
      categoryId: 2,
      categoryName: 'เครื่องเสียง',
      assetCode: 'MIC-001',
      status: EquipmentStatus.available,
      pricePerDay: 300,
      deposit: 2000,
    ),
    Equipment(
      id: 5,
      name: 'ลำโพงบลูทูธ',
      categoryId: 2,
      categoryName: 'เครื่องเสียง',
      assetCode: 'SPK-001',
      status: EquipmentStatus.maintenance,
      pricePerDay: 300,
      deposit: 2000,
    ),
    Equipment(
      id: 6,
      name: 'วอล์กกี้ทอล์กกี้ Motorola',
      categoryId: 3,
      categoryName: 'วิทยุสื่อสาร',
      assetCode: 'WT-005',
      status: EquipmentStatus.borrowed,
      pricePerDay: 300,
      deposit: 2000,
    ),
  ];
}

Equipment eq(
  int id, {
  String? name,
  String? code,
  int categoryId = 1,
  String categoryName = 'กล้อง',
  EquipmentStatus status = EquipmentStatus.available,
  double price = 0,
  double deposit = 0,
}) => Equipment(
  id: id,
  assetCode: code ?? 'EQ-$id',
  name: name ?? 'อุปกรณ์ $id',
  categoryId: categoryId,
  categoryName: categoryName,
  status: status,
  pricePerDay: price,
  deposit: deposit,
);
