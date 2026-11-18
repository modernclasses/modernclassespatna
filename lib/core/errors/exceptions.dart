/// Exception classes thrown by datasources and external services.
class AppException implements Exception {
  final String message;
  final dynamic details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Server exception occurred',
    super.details,
  ]);
}

class AuthException extends AppException {
  const AuthException([
    super.message = 'Authentication exception occurred',
    super.details,
  ]);
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connection failure',
    super.details,
  ]);
}

class ValidationException extends AppException {
  const ValidationException([
    super.message = 'Validation exception occurred',
    super.details,
  ]);
}
