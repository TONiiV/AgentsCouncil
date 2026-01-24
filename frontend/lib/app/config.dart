/// API configuration
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPath = '/api';
  static const String wsPath = '/ws';
  
  static String get apiUrl => '$baseUrl$apiPath';
  static String get wsUrl => 'ws://localhost:8000$wsPath';
}
