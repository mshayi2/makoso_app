class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'MAKOSO_API_BASE_URL',
    defaultValue: 'https://makoso.menji-group.com',
  );

  static const String apiKey =
      'mQO-MgS8ql6XlW-6Dyx02dice5wR1_wQrqx9_x62X-TIPWjRySsgmfpsF8lwz5l-';

  static const Map<String, String> authorizationHeaders = {
    'Accept': 'application/json',
    'Authorization': 'Bearer $apiKey',
    'X-Client-Type': 'flutter',
  };

  static const Map<String, String> defaultHeaders = {
    ...authorizationHeaders,
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
