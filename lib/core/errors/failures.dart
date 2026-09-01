/// Base failure class for domain/UI layer error presentation.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([String message = 'A server error occurred. Please try again later.'])
      : super(message);
}

class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication failed. Please verify credentials.'])
      : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection. Please check your network.'])
      : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure([String message = 'Failed to load cached local data.'])
      : super(message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
