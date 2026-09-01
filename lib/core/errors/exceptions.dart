/// Exception classes thrown by datasources and external services.
class AppException implements Exception {
  final String message;
  final dynamic details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException([String message = 'Server exception occurred', dynamic details])
      : super(message, details);
}

class AuthException extends AppException {
  const AuthException([String message = 'Authentication exception occurred', dynamic details])
      : super(message, details);
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Network connection failure', dynamic details])
      : super(message, details);
}
