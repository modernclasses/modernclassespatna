/// Base failure class for domain/UI layer error presentation.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'A server error occurred. Please try again later.',
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Authentication failed. Please verify credentials.',
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to load cached local data.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
