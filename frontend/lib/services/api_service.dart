import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/config.dart';
import '../models/models.dart';

/// API service for communicating with the backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  // Guest ID for unauthenticated requests
  String? _guestId;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth headers based on current auth state
        _addAuthHeaders(options);
        handler.next(options);
      },
    ));

    // Add logging interceptor for debug
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Set the guest ID for unauthenticated requests
  void setGuestId(String? guestId) {
    _guestId = guestId;
  }

  /// Add auth headers to request options
  void _addAuthHeaders(RequestOptions options) {
    try {
      // Try to get Supabase session first
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        return;
      }
    } catch (_) {
      // Supabase not initialized yet, fall through to guest ID
    }

    // Fall back to guest ID header
    if (_guestId != null) {
      options.headers['X-Guest-Id'] = _guestId;
    }
  }

  // === Providers ===

  Future<List<String>> getAvailableProviders() async {
    final response = await _dio.get('/councils/providers');
    return (response.data['available'] as List).cast<String>();
  }

  Future<List<String>> getProviderModels(String provider) async {
    final response = await _dio.get('/providers/$provider/models');
    return (response.data['models'] as List).cast<String>();
  }

  // === Roles ===

  Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await _dio.get('/councils/roles');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  // === Councils ===

  Future<CouncilConfig> createCouncil({
    required String name,
    required List<AgentConfig> agents,
    int maxRounds = 5,
    double consensusThreshold = 0.8,
  }) async {
    final response = await _dio.post('/councils', data: {
      'name': name,
      'agents': agents.map((a) => a.toJson()).toList(),
      'max_rounds': maxRounds,
      'consensus_threshold': consensusThreshold,
    });
    return CouncilConfig.fromJson(response.data);
  }

  Future<List<CouncilConfig>> listCouncils() async {
    final response = await _dio.get('/councils');
    return (response.data as List)
        .map((c) => CouncilConfig.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<CouncilConfig> getCouncil(String councilId) async {
    final response = await _dio.get('/councils/$councilId');
    return CouncilConfig.fromJson(response.data);
  }

  Future<CouncilConfig> updateCouncil(
    String councilId, {
    required String name,
    required List<AgentConfig> agents,
    int maxRounds = 5,
    double consensusThreshold = 0.8,
  }) async {
    final response = await _dio.put('/councils/$councilId', data: {
      'name': name,
      'agents': agents.map((a) => a.toJson()).toList(),
      'max_rounds': maxRounds,
      'consensus_threshold': consensusThreshold,
    });
    return CouncilConfig.fromJson(response.data);
  }

  Future<void> deleteCouncil(String councilId) async {
    await _dio.delete('/councils/$councilId');
  }

  // === Debates ===

  Future<Debate> startDebate({
    required String councilId,
    required String topic,
  }) async {
    final response = await _dio.post('/debates', data: {
      'council_id': councilId,
      'topic': topic,
    });
    return Debate.fromJson(response.data);
  }

  Future<List<Debate>> listDebates({String? councilId}) async {
    final response = await _dio.get(
      '/debates',
      queryParameters: councilId != null ? {'council_id': councilId} : null,
    );
    return (response.data as List)
        .map((d) => Debate.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<Debate> getDebate(String debateId) async {
    final response = await _dio.get('/debates/$debateId');
    return Debate.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getDebateSummary(String debateId) async {
    final response = await _dio.get('/debates/$debateId/summary');
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelDebate(String debateId) async {
    await _dio.post('/debates/$debateId/cancel');
  }

  Future<void> deleteDebate(String debateId) async {
    await _dio.delete('/debates/$debateId');
  }

  // === Auth ===

  /// Claim guest data and migrate it to the authenticated user's account
  Future<void> claimGuestData(String guestId) async {
    await _dio.post('/auth/claim', data: {
      'guest_id': guestId,
    });
  }

  // === Health ===

  Future<bool> checkHealth() async {
    try {
      // Health endpoint is at root level, not under /api
      final response = await Dio().get('${ApiConfig.baseUrl}/health');
      return response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }
}
