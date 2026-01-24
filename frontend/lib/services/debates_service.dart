import 'package:supabase_flutter/supabase_flutter.dart';

/// Model for a debate record
class Debate {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? content;

  Debate({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.content,
  });

  factory Debate.fromJson(Map<String, dynamic> json) {
    return Debate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      content: json['content'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'content': content,
    };
  }
}

/// Service for managing debates in Supabase
class DebatesService {
  final SupabaseClient _supabase;

  DebatesService(this._supabase);

  /// Create a new debate
  Future<Debate> createDebate({
    required String title,
    Map<String, dynamic>? content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated to create a debate');
      }

      final response = await _supabase
          .from('debates')
          .insert({
            'user_id': userId,
            'title': title,
            'content': content,
          })
          .select()
          .single();

      return Debate.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create debate: $e');
    }
  }

  /// Get all debates for the current user
  Future<List<Debate>> getDebates({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated to fetch debates');
      }

      final response = await _supabase
          .from('debates')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => Debate.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch debates: $e');
    }
  }

  /// Get a single debate by ID
  Future<Debate> getDebate(String debateId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _supabase
          .from('debates')
          .select()
          .eq('id', debateId)
          .eq('user_id', userId)
          .single();

      return Debate.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch debate: $e');
    }
  }

  /// Update an existing debate
  Future<Debate> updateDebate({
    required String debateId,
    String? title,
    Map<String, dynamic>? content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;

      if (updates.isEmpty) {
        throw Exception('No fields to update');
      }

      final response = await _supabase
          .from('debates')
          .update(updates)
          .eq('id', debateId)
          .eq('user_id', userId)
          .select()
          .single();

      return Debate.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update debate: $e');
    }
  }

  /// Delete a debate
  Future<void> deleteDebate(String debateId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      await _supabase
          .from('debates')
          .delete()
          .eq('id', debateId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete debate: $e');
    }
  }

  /// Stream debates for real-time updates
  Stream<List<Debate>> streamDebates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    return _supabase
        .from('debates')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => Debate.fromJson(json as Map<String, dynamic>))
            .toList());
  }
}
