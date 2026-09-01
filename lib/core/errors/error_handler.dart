import 'failures.dart';
import 'exceptions.dart';

/// Centralized Error Handler to map raw exceptions to clean domain Failures.
class ErrorHandler {
  ErrorHandler._();

  static Failure handle(Object error) {
    if (error is Failure) return error;

    if (error is NetworkException) {
      return const NetworkFailure();
    }

    if (error is AuthException) {
      return AuthFailure(error.message);
    }

    if (error is ServerException) {
      return ServerFailure(error.message);
    }

    final message = error.toString().replaceAll('Exception:', '').trim();
    if (message.toLowerCase().contains('socket') ||
        message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('connection')) {
      return const NetworkFailure();
    }

    return ServerFailure(message.isNotEmpty ? message : 'An unexpected error occurred.');
  }
}
