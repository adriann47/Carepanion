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

  /// Fetch the profile row for the supplied [id] or the current auth user.
  static Future<Map<String, dynamic>?> fetchProfile(
    SupabaseClient client, {
    String? userId,
  }) async {
    final id = userId ?? client.auth.currentUser?.id;
    if (id == null) return null;
    final table = await _resolveTable(client);
    return client.from(table).select().eq('id', id).maybeSingle();
  }

  /// Persists the supplied [avatarUrl] against the profile row.
  static Future<void> updateAvatarUrl(
    SupabaseClient client, {
    required String userId,
    required String avatarUrl,
  }) async {
    final table = await _resolveTable(client);
    await client.from(table).update({'avatar_url': avatarUrl}).eq('id', userId);
  }

  /// Upload raw image [bytes] to the `avatars` storage bucket and return paths.
  static Future<AvatarUploadResult> uploadAvatar(
    SupabaseClient client, {
    required Uint8List bytes,
    required String fileExt,
    required String userId,
  }) async {
    final storage = client.storage.from('avatars');
    final safeExt = fileExt.toLowerCase();
    final path = '$userId/avatar.$safeExt';
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: _resolveMimeType(safeExt),
      ),
    );
    final publicUrl = storage.getPublicUrl(path);
    return AvatarUploadResult(path: path, publicUrl: publicUrl);
  }

  static String _resolveMimeType(String ext) {
    switch (ext.replaceAll('.', '')) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }
}

/// Result payload returned after uploading an avatar image.
class AvatarUploadResult {
  AvatarUploadResult({required this.path, required this.publicUrl});

  final String path;
  final String publicUrl;
}
