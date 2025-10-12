import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized profile persistence that auto-detects the correct table name.
class ProfileService {
  ProfileService._();

  // Common candidates seen across projects; includes a space variant if created oddly in UI.
  static const List<String> _candidates = [
    'profile',
    'profiles',
    'profile table',
    'profile_table',
  ];

  static String? _resolvedTable;

  /// Explicitly set the profile table name to avoid runtime probing.
  static void setPreferredTable(String tableName) {
    _resolvedTable = tableName;
  }

  /// Resolve and cache the available profile table by probing candidates.
  static Future<String> _resolveTable(SupabaseClient client) async {
    if (_resolvedTable != null) return _resolvedTable!;
    for (final name in _candidates) {
      try {
        // Harmless probe: select first row's id if present
        await client.from(name).select('id').limit(1).maybeSingle();
        _resolvedTable = name;
        return name;
      } catch (_) {
        // Try next candidate
        continue;
      }
    }
    // Fallback to 'profile' which matches your current schema
    _resolvedTable = 'profile';
    return _resolvedTable!;
  }

  /// Ensures a profile exists for the current auth user; creates one if missing.
  static Future<void> ensureProfileExists(
    SupabaseClient client, {
    String? email,
    String? fullName,
    String? role,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final table = await _resolveTable(client);
    try {
      final payload = <String, dynamic>{'id': user.id};
      if (email != null) payload['email'] = email;
      if (fullName != null) payload['fullname'] = fullName;
      if (role != null) payload['role'] = role;
      await client.from(table).upsert(payload);
    } catch (_) {
      // Swallow and let caller decide user-facing handling
    }
  }

  /// Upsert a profile row with the provided fields.
  static Future<void> upsertProfile(
    SupabaseClient client, {
    required String id,
    String? email,
    String? fullName,
    String? role,
  }) async {
    final table = await _resolveTable(client);
    final payload = <String, dynamic>{'id': id};
    if (email != null) payload['email'] = email;
    if (fullName != null) payload['fullname'] = fullName;
    if (role != null) payload['role'] = role;
    await client.from(table).upsert(payload);
  }

  /// Fetch the current user's role string from the profile table.
  /// Returns null if no row or no role.
  static Future<String?> getCurrentUserRole(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final table = await _resolveTable(client);
    try {
      final data = await client
          .from(table)
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      final dynamic r = data['role'];
      if (r == null) return null;
      final s = r.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }
}
