import 'dart:typed_data';

import 'dart:math';
import 'package:flutter/foundation.dart';
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
    // If role not provided, try to read it from user metadata set during signup
    String? effectiveRole = role;
    try {
      final raw = user.userMetadata;
      if (effectiveRole == null && raw is Map<String, dynamic>) {
        final dynamic metaRole = raw['role'];
        if (metaRole != null) {
          final sr = metaRole.toString().trim();
          if (sr.isNotEmpty) effectiveRole = sr;
        }
      }
    } catch (_) {}
    final table = await _resolveTable(client);
    try {
      final payload = <String, dynamic>{'id': user.id};
      if (email != null) payload['email'] = email;
      if (fullName != null) payload['fullname'] = fullName;
      if (effectiveRole != null) payload['role'] = effectiveRole;

      // If this is a regular user, ensure they have a short public_id (8 digits)
      if (effectiveRole != null && effectiveRole.toLowerCase() == 'regular') {
        // Check existing row for public_id
        try {
          final existing = await client.from(table).select('public_id').eq('id', user.id).maybeSingle();
          final existingId = existing == null ? null : (existing['public_id'] as dynamic);
          if (existingId == null) {
            // generate unique 8-digit numeric id
            final pub = await _generateUniquePublicId(client, table);
            if (pub != null) payload['public_id'] = pub;
          }
        } catch (_) {
          // ignore and continue; the upsert below will still run
        }
      }

      await client.from(table).upsert(payload);
    } catch (e) {
      // During development, surface DB errors so we can debug why the upsert failed.
      if (kDebugMode) {
        // ignore: avoid_print
        print('ProfileService.ensureProfileExists error: $e');
      }
      // Swallow in production to preserve existing behaviour
    }
  }

  /// Generate a unique 8-digit numeric public_id not already present in the
  /// profile table. Returns null if generation failed (after attempts).
  static Future<String?> _generateUniquePublicId(SupabaseClient client, String table) async {
    final rng = Random.secure();
    const attempts = 6;
    for (var i = 0; i < attempts; i++) {
      final value = (rng.nextInt(90000000) + 10000000).toString(); // 8 digits, first digit non-zero
      try {
        final found = await client.from(table).select('id').eq('public_id', value).maybeSingle();
        if (found == null) {
          return value;
        }
      } catch (_) {
        // if query fails, try again
        continue;
      }
    }
    return null;
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

/// Result payload returned after uploading an avatar image.
class AvatarUploadResult {
  AvatarUploadResult({required this.path, required this.publicUrl});

  final String path;
  final String publicUrl;
}
