import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/debates_service.dart';

/// Provider for the DebatesService singleton
final debatesServiceProvider = Provider<DebatesService>((ref) {
  return DebatesService(Supabase.instance.client);
});

/// Provider that streams all debates for the current user
final debatesStreamProvider = StreamProvider<List<Debate>>((ref) {
  final debatesService = ref.watch(debatesServiceProvider);
  return debatesService.streamDebates();
});

/// Provider to fetch debates list (FutureProvider)
final debatesListProvider = FutureProvider<List<Debate>>((ref) {
  final debatesService = ref.watch(debatesServiceProvider);
  return debatesService.getDebates();
});

/// Provider to fetch a single debate by ID
final debateProvider = FutureProvider.family<Debate, String>((ref, debateId) {
  final debatesService = ref.watch(debatesServiceProvider);
  return debatesService.getDebate(debateId);
});
