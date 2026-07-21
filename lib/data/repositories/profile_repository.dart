import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// Ports `useMyProfile`, `useProfiles`, `useIsAdmin`, the Contacts tab's
/// search query, and `find_user_by_phone` from `src/lib/tickbell.ts` and
/// `home.tsx`.
class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<Profile?> fetchMyProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<List<Profile>> fetchAllProfiles() async {
    final rows = await _client.from('profiles').select().order('display_name');
    return (rows as List).map((r) => Profile.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Contacts tab search — matches display_name/email via ilike, excluding self.
  Future<List<Profile>> searchContacts({required String currentUserId, String query = ''}) async {
    var builder = _client.from('profiles').select().neq('id', currentUserId);
    final term = query.trim();
    if (term.isNotEmpty) {
      final like = '%${term.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      builder = builder.or('display_name.ilike.$like,email.ilike.$like');
    }
    final rows = await builder.order('display_name').limit(200);
    return (rows as List).map((r) => Profile.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// `has_role(_user_id, 'admin')` RPC — used to show the shield-alert admin
  /// entry point on Home and to gate the Blocks screen.
  Future<bool> isAdmin(String userId) async {
    try {
      final res = await _client.rpc('has_role', params: {'_user_id': userId, '_role': 'admin'});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// `find_user_by_phone` RPC — used by the "Find by phone number" flow.
  Future<Profile?> findUserByPhone(String phone) async {
    final rows = await _client.rpc('find_user_by_phone', params: {'_phone': phone});
    final list = rows as List?;
    if (list == null || list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    // find_user_by_phone only returns id/display_name/avatar_url; wrap the
    // rest with sensible defaults so Profile.fromJson doesn't choke.
    return Profile.fromJson({
      ...row,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateMyProfile({
    required String userId,
    required String displayName,
    String? statusMessage,
    String? avatarUrl,
    String? phone,
  }) async {
    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'status_message': (statusMessage?.trim().isEmpty ?? true) ? null : statusMessage!.trim(),
      'avatar_url': (avatarUrl?.trim().isEmpty ?? true) ? null : avatarUrl!.trim(),
      'phone': (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
    }).eq('id', userId);
  }
}
