class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  @override
  String toString() => '[$statusCode/$code] $message';
}
