/// Application level domain and infrastructure exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.code]);
}

class NetworkException extends AppException {
  const NetworkException(super.message, [super.code]);
}

class ModelPredictionException extends AppException {
  const ModelPredictionException(super.message, [super.code]);
}

class ResourceNotFoundException extends AppException {
  const ResourceNotFoundException(super.message, [super.code]);
}
