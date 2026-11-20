class ApiConfig {
  const ApiConfig._();

  // Production API. Override this at build time for local development or
  // alternate deployments.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hazardheroapi.site',
  );
  static String get _normalizedBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  static String get normalizedBaseUrl => _normalizedBaseUrl;
  static String get healthUrl => '$_normalizedBaseUrl/health/';
  static String get citizenBase => '$_normalizedBaseUrl/api/citizen';
  static String get responderBase => '$_normalizedBaseUrl/api/responder';
  static const timeout = Duration(seconds: 20);
}
