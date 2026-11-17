import 'package:frontend/core/api_client.dart';

/// An error whose [message] is meant to be shown to the user as-is (Thai text).
///
/// The test controllers recognize it through their `ApiException` handling.
class AppException extends ApiException {
  const AppException(super.message);
}
