/// API configuration
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPath = '/api';
  static const String wsPath = '/ws';

  static String get apiUrl => '$baseUrl$apiPath';
  static String get wsUrl => 'ws://localhost:8000$wsPath';
}

/// Supabase configuration
class SupabaseConfig {
  static const String url = 'https://qqtwgjctypskvergeykt.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxdHdnamN0eXBza3ZlcmdleWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyNjY0MjksImV4cCI6MjA4NDg0MjQyOX0.3_bM_vx9dVvioiIPes-6PRQ7owLQpnn_UuVqaxgAAuI';
}
