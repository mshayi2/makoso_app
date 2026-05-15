class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'MAKOSO_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Uri uri(String endpoint) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';
    return Uri.parse('$normalizedBase$normalizedEndpoint');
  }
}