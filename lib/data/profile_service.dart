import 'dart:typed_data';
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

  /// Link the current user (assisted) to a guardian by their `public_id`.
  /// Returns true on success, false if guardian not found.
  static Future<bool> linkGuardianByPublicId(
    SupabaseClient client, {
    required String guardianPublicId,
  }) async {
    // Find guardian row by public_id
    try {
      final table = await _resolveTable(client);
      final guardian = await client.from(table).select('id').eq('public_id', guardianPublicId).maybeSingle();
      if (guardian == null) return false;
      final guardianId = guardian['id'] as String;
      final user = client.auth.currentUser;
      if (user == null) return false;
      await client.from(table).update({'guardian_id': guardianId}).eq('id', user.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Given a guardian's user id, return a list of assisted users (their profile rows)
  /// who have this guardian linked. Returns empty list if none or on error.
  static Future<List<Map<String, dynamic>>> fetchAssistedsForGuardian(
    SupabaseClient client, {
    required String guardianUserId,
  }) async {
    try {
      final table = await _resolveTable(client);
      final res = await client.from(table).select().eq('guardian_id', guardianUserId);
      // Supabase returns a List of maps on success; cast accordingly.
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  /// Upsert a profile row with the provided fields.
  static Future<void> upsertProfile(
    SupabaseClient client, {
    required String id,
    String? email,
    String? fullName,
    String? role,
    String? birthday,
  }) async {
    final table = await _resolveTable(client);
    final payload = <String, dynamic>{'id': id};
    if (email != null) payload['email'] = email;
    if (fullName != null) payload['fullname'] = fullName;
    if (role != null) payload['role'] = role;
    if (birthday != null) payload['birthday'] = birthday;
    await client.from(table).upsert(payload);
  }

  /// Fetch current user's profile row (or specific [userId] if provided).
  /// Returns a map of columns or null if not found.
  static Future<Map<String, dynamic>?> fetchProfile(
    SupabaseClient client, {
    String? userId,
  }) async {
    final user = userId != null ? null : client.auth.currentUser;
    final id = userId ?? user?.id;
    if (id == null) return null;
    final table = await _resolveTable(client);
    try {
      final data = await client
          .from(table)
          .select()
          .eq('id', id)
          .limit(1)
          .maybeSingle();
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Upload avatar bytes to the 'avatars' storage bucket for the given user.
  /// Returns a public URL to the uploaded image.
  static Future<ProfileAvatarUploadResult> uploadAvatar(
    SupabaseClient client, {
    required Uint8List bytes,
    required String fileExt,
    required String userId,
  }) async {
    // Normalize extension
    final ext = fileExt.toLowerCase().replaceAll('.', '');
    final path = 'avatars/$userId/avatar.$ext';

    // Upsert upload so subsequent changes overwrite
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: 'image/$ext',
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);
    return ProfileAvatarUploadResult(publicUrl: publicUrl);
  }

  /// Update the avatar_url column for a given user id.
  static Future<void> updateAvatarUrl(
    SupabaseClient client, {
    required String userId,
    required String avatarUrl,
  }) async {
    final table = await _resolveTable(client);
    await client.from(table).update({'avatar_url': avatarUrl}).eq('id', userId);
  }
}

/// Simple value class for avatar upload results.
class ProfileAvatarUploadResult {
  final String publicUrl;
  const ProfileAvatarUploadResult({required this.publicUrl});
}
