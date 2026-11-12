import 'dart:convert';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fakes.dart';

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const userJson = {
  'id': 7,
  'username': '6731500002',
  'full_name': 'มาลี รักเรียน',
  'role': 'borrower',
};

void main() {
  late MemoryTokenStore tokens;
  late List<http.Request> sent;
  late ApiClient api;
  late ApiAuthRepository repo;

  /// Builds the repo with a fake server that answers every request with [reply].
  void useServer(http.Response Function(http.Request) reply) {
    sent = [];
    api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        sent.add(request);
        return reply(request);
      }),
    );
    repo = ApiAuthRepository(api, tokens);
  }

  setUp(() => tokens = MemoryTokenStore());

  group('register', () {
    test('sends only username, full_name and password - never a role', () async {
      useServer((_) => json({'token': 'tok', 'user': userJson}, 201));

      final user = await repo.register(
        username: '6731500002',
        fullName: 'มาลี รักเรียน',
        password: 'secret123',
      );

      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/register');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {
        'username': '6731500002',
        'full_name': 'มาลี รักเรียน',
        'password': 'secret123',
      });
      expect(body.containsKey('role'), isFalse);

      expect(user.role, UserRole.borrower);
      expect(tokens.token, 'tok');
      expect(api.token, 'tok');
    });

    test('a taken student id surfaces as an ApiException with the server message', () async {
      useServer((_) => json({
            'error': {'code': 'USERNAME_TAKEN', 'message': 'รหัสนักศึกษานี้ถูกใช้งานแล้ว'},
          }, 409));

      await expectLater(
        repo.register(username: '6731500002', fullName: 'x', password: 'secret123'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'USERNAME_TAKEN')
            .having((e) => e.message, 'message', 'รหัสนักศึกษานี้ถูกใช้งานแล้ว')),
      );
      expect(tokens.token, isNull);
    });
  });

  group('login', () {
    test('stores the token and returns the user', () async {
      useServer((_) => json({'token': 'tok', 'user': userJson}));

      final user = await repo.login(username: '6731500002', password: 'secret123');

      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(sent.single.url.path, '/api/auth/login');
      expect(body, {'username': '6731500002', 'password': 'secret123'});
      expect(user.fullName, 'มาลี รักเรียน');
      expect(tokens.token, 'tok');
      expect(api.token, 'tok');
    });

    test('wrong password is an ApiException and does not count as an expired session', () async {
      useServer((_) => json({
            'error': {
              'code': 'INVALID_CREDENTIALS',
              'message': 'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง',
            },
          }, 401));
      var expiredCalls = 0;
      api.onUnauthorized = () => expiredCalls++;

      await expectLater(
        repo.login(username: '6731500002', password: 'nope'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );

      expect(expiredCalls, 0); // no token was sent, so nothing "expired"
      expect(tokens.token, isNull);
    });

    test('a network failure becomes a readable ApiException', () async {
      useServer((_) => throw http.ClientException('connection refused'));

      await expectLater(
        repo.login(username: '6731500002', password: 'secret123'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK')),
      );
    });
  });

  group('restoreSession', () {
    test('returns null without calling the server when no token is saved', () async {
      useServer((_) => json({}));

      expect(await repo.restoreSession(), isNull);
      expect(sent, isEmpty);
    });

    test('sends the saved token and returns the user', () async {
      tokens.token = 'saved';
      useServer((_) => json({'user': userJson}));

      final user = await repo.restoreSession();

      expect(user?.username, '6731500002');
      expect(sent.single.url.path, '/api/auth/me');
      expect(sent.single.headers['authorization'], 'Bearer saved');
    });

    test('an expired token is cleared and gives null', () async {
      tokens.token = 'expired';
      useServer((_) => json({
            'error': {'code': 'UNAUTHORIZED', 'message': 'เซสชันหมดอายุ'},
          }, 401));

      expect(await repo.restoreSession(), isNull);
      expect(tokens.token, isNull);
      expect(api.token, isNull);
    });

    test('being offline keeps the token so the user can retry', () async {
      tokens.token = 'saved';
      useServer((_) => throw http.ClientException('offline'));

      await expectLater(repo.restoreSession(), throwsA(isA<ApiException>()));
      expect(tokens.token, 'saved');
    });
  });

  test('logout forgets the token everywhere', () async {
    tokens.token = 'saved';
    useServer((_) => json({}));
    api.token = 'saved';

    await repo.logout();

    expect(tokens.token, isNull);
    expect(api.token, isNull);
  });
}
