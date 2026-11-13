import 'dart:async';

import 'package:frontend/core/models.dart';
import 'package:frontend/features/auth/auth_repository.dart';
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
  final registerCalls = <({String username, String fullName, String password})>[];

  @override
  Future<AppUser> login({required String username, required String password}) async {
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
    registerCalls.add((username: username, fullName: fullName, password: password));
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
  })  : equipment = equipment ?? [],
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

Equipment eq(
  int id, {
  String? name,
  String? code,
  int categoryId = 1,
  String categoryName = 'กล้อง',
  EquipmentStatus status = EquipmentStatus.available,
  double price = 0,
  double deposit = 0,
}) =>
    Equipment(
      id: id,
      assetCode: code ?? 'EQ-$id',
      name: name ?? 'อุปกรณ์ $id',
      categoryId: categoryId,
      categoryName: categoryName,
      status: status,
      pricePerDay: price,
      deposit: deposit,
    );
