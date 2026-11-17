/// An error whose [message] is meant to be shown to the user as-is (Thai text).
///
/// Controllers catch this type only, so they work with any data source:
/// the real backend (`ApiException` extends it), the mock repositories, or the
/// group's AppStore. Throw `AppException('...')` from your own repositories.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
