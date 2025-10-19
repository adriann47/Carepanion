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
        continue;
      }
    }
    _resolvedTable = 'profile'; // fallback
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

    // Try to determine role from metadata if not provided
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
      // 1) Read existing row once
      final existing = await client
          .from(table)
          .select('id, email, fullname, role, public_id')
          .eq('id', user.id)
          .maybeSingle();

      // 2) If no row, insert with provided metadata (including fullname if available)
      if (existing == null) {
        final insertPayload = <String, dynamic>{
          'id': user.id,
          if (email != null) 'email': email,
          if (fullName != null && fullName.trim().isNotEmpty)
            'fullname': fullName.trim(),
          if (effectiveRole != null) 'role': effectiveRole,
        };

        // Generate public_id for new Regular users
        if ((effectiveRole ?? '').toLowerCase() == 'regular') {
          final pub = await _generateUniquePublicId(client, table);
          if (pub != null) insertPayload['public_id'] = pub;
        }

        await client.from(table).insert(insertPayload);
        return;
      }

      // 3) Row exists — only patch missing fields. Never overwrite an existing fullname here.
      final updatePayload = <String, dynamic>{};

      // Set email if currently null and we have one
      final dynamic existingEmail = existing['email'];
      if ((existingEmail == null || existingEmail.toString().trim().isEmpty) &&
          email != null) {
        updatePayload['email'] = email;
      }

      // Set role if currently null and we have one
      final dynamic existingRole = existing['role'];
      if ((existingRole == null || existingRole.toString().trim().isEmpty) &&
          effectiveRole != null) {
        updatePayload['role'] = effectiveRole;
      }

      // Ensure Regular users have public_id; don't touch if it already exists
      final dynamic existingPublicId = existing['public_id'];
      if ((effectiveRole ?? existingRole?.toString() ?? '').toLowerCase() ==
          'regular') {
        if (existingPublicId == null ||
            existingPublicId.toString().trim().isEmpty) {
          final pub = await _generateUniquePublicId(client, table);
          if (pub != null) updatePayload['public_id'] = pub;
        }
      }

      if (updatePayload.isNotEmpty) {
        await client.from(table).update(updatePayload).eq('id', user.id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProfileService.ensureProfileExists error: $e');
      }
    }
  }

  /// Generate a unique 8-digit numeric public_id not already present.
  static Future<String?> _generateUniquePublicId(
    SupabaseClient client,
    String table,
  ) async {
    final rng = Random.secure();
    const attempts = 6;
    for (var i = 0; i < attempts; i++) {
      final value = (rng.nextInt(90000000) + 10000000)
          .toString(); // 8-digit number
      try {
        final found = await client
            .from(table)
            .select('id')
            .eq('public_id', value)
            .maybeSingle();
        if (found == null) return value;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Link the current user (assisted) to a guardian by their `public_id`.
  /// Returns true on success, false if guardian not found.
  static Future<bool> linkGuardianByPublicId(
    SupabaseClient client, {
    required String guardianPublicId,
  }) async {
    try {
      final table = await _resolveTable(client);
      final guardian = await client
          .from(table)
          .select('id')
          .eq('public_id', guardianPublicId)
          .maybeSingle();
      if (guardian == null) return false;
      final guardianId = guardian['id'] as String;
      final user = client.auth.currentUser;
      if (user == null) return false;
      await client
          .from(table)
          .update({'guardian_id': guardianId})
          .eq('id', user.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Instead of directly linking, create a guardian request row in
  /// `assisted_guardians` with status 'pending'. Returns true if the
  /// request was created.
  /// Create a guardian request row in `assisted_guardians` with status 'pending'.
  /// Throws an exception with a helpful message on failure.
  static Future<void> requestGuardianByPublicId(
    SupabaseClient client, {
    required String guardianPublicId,
  }) async {
    final table = await _resolveTable(client);

    // Try to locate guardian by multiple likely columns (public_id, share_code)
    Map<String, dynamic>? guardian;
    try {
      guardian = await client
          .from(table)
          .select('id')
          .or('public_id.eq.$guardianPublicId,share_code.eq.$guardianPublicId')
          .maybeSingle();
    } catch (e) {
      throw Exception('Failed to query profile table: $e');
    }

    if (guardian == null)
      throw Exception('Guardian not found for id $guardianPublicId');
    final guardianId = guardian['id'] as String;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Prevent duplicate pending requests to same guardian
    try {
      final exists = await client
          .from('assisted_guardians')
          .select('id')
          .eq('assisted_id', user.id)
          .eq('guardian_id', guardianId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();
      if (exists != null) return; // already pending
    } catch (e) {
      throw Exception('Failed to check existing requests: $e');
    }

    // Insert request row
    try {
      await client.from('assisted_guardians').insert({
        'assisted_id': user.id,
        'guardian_id': guardianId,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception(
        'Failed to create guardian request (assisted_guardians table may be missing): $e',
      );
    }
  }

  /// Poll for guardian response for the currently authenticated user.
  /// Returns 'accepted'|'rejected'|'timeout'.
  static Future<String> waitForGuardianResponse(
    SupabaseClient client, {
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return 'timeout';

    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      try {
        final row = await client
            .from('assisted_guardians')
            .select('status')
            .eq('assisted_id', user.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (row != null && row['status'] != null) {
          final status = row['status'] as String;
          if (status == 'accepted' || status == 'rejected') return status;
        }
      } catch (_) {}
      await Future.delayed(pollInterval);
    }
    return 'timeout';
  }

  /// Fetch all assisted users for a given guardian ID.
  static Future<List<Map<String, dynamic>>> fetchAssistedsForGuardian(
    SupabaseClient client, {
    required String guardianUserId,
  }) async {
    try {
      final table = await _resolveTable(client);

      // 1) Legacy single-link via profile.guardian_id
      List legacy = [];
      try {
        legacy = await client
            .from(table)
            .select()
            .eq('guardian_id', guardianUserId);
      } catch (_) {}

      // 2) Multi-link via assisted_guardians join table - only accepted status
      final Set<String> ids = <String>{};
      for (final r in legacy) {
        final id = r['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      try {
        final links = await client
            .from('assisted_guardians')
            .select('assisted_id')
            .eq('guardian_id', guardianUserId)
            .eq('status', 'accepted'); // Only accepted requests
        for (final e in links as List) {
          final v = e['assisted_id']?.toString();
          if (v != null && v.isNotEmpty) ids.add(v);
        }
      } catch (_) {}

      if (ids.isEmpty) return List<Map<String, dynamic>>.from(legacy);

      // Fetch full profiles for union set
      final rows = await client
          .from(table)
          .select()
          .inFilter('id', ids.toList());
      return List<Map<String, dynamic>>.from(rows as List);
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
    String? phone,
  }) async {
    final table = await _resolveTable(client);
    final payload = <String, dynamic>{'id': id};
    if (email != null) payload['email'] = email;
    if (fullName != null) payload['fullname'] = fullName;
    if (role != null) payload['role'] = role;
    if (birthday != null) payload['birthday'] = birthday;

    try {
      await client.from(table).upsert(payload);
    } catch (e) {
      // Don't let DB policy failures block client flows like registration.
      // Log the error for debugging in dev mode and continue.
      if (kDebugMode) {
        // ignore: avoid_print
        print('ProfileService.upsertProfile failed: $e');
      }

      if (phone != null)
        payload['phone'] = phone; // best-effort; may fail if column missing
      try {
        await client.from(table).upsert(payload);
      } catch (_) {
        // If 'phone' column doesn't exist, ignore; callers can use setPhone for robust writes
        await client.from(table).upsert({
          'id': id,
          if (email != null) 'email': email,
          if (fullName != null) 'fullname': fullName,
          if (role != null) 'role': role,
          if (birthday != null) 'birthday': birthday,
        });
      }
    }
  }

  /// Fetch the profile row for the supplied [id] or the current auth user.
  static Future<Map<String, dynamic>?> fetchProfile(
    SupabaseClient client, {
    String? userId,
  }) async {
    final id = userId ?? client.auth.currentUser?.id;
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

  /// Update the avatar URL column for a given user id.
  static Future<void> updateAvatarUrl(
    SupabaseClient client, {
    required String userId,
    required String avatarUrl,
  }) async {
    final table = await _resolveTable(client);
    await client.from(table).update({'avatar_url': avatarUrl}).eq('id', userId);
  }

  /// Upload avatar bytes to the `avatars` storage bucket and return result.
  static Future<AvatarUploadResult> uploadAvatar(
    SupabaseClient client, {
    required Uint8List bytes,
    required String fileExt,
    required String userId,
  }) async {
    final storage = client.storage.from('avatars');
    final safeExt = fileExt.toLowerCase().replaceAll('.', '');
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
    switch (ext) {
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

  /// Robustly set a phone/mobile field for the given user id, trying common column names.
  /// Tries 'phone', then 'mobile', then 'mobile_number'. Returns true on success.
  static Future<bool> setPhone(
    SupabaseClient client, {
    required String id,
    required String phone,
  }) async {
    final table = await _resolveTable(client);
    final List<String> columns = ['phone', 'mobile', 'mobile_number'];
    for (final col in columns) {
      try {
        await client.from(table).update({col: phone}).eq('id', id);
        return true;
      } catch (_) {
        continue;
      }
    }
    // If update failed (row might not exist), try insert/upsert with each column
    for (final col in columns) {
      try {
        await client.from(table).upsert({'id': id, col: phone});
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Helper to read a phone/mobile value from a profile map using common keys.
  static String? readPhoneFrom(Map<String, dynamic>? data) {
    if (data == null) return null;
    final keys = ['phone', 'mobile', 'mobile_number'];
    for (final k in keys) {
      final v = data[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  /// Read common birthday fields and return a readable string like "January 2, 1990" or null.
  static String? readBirthdayFrom(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = (data['birthday'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      final months = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return null;
    }
  }

  /// Best-effort helper to set guardian_id on the assisted user's profile row.
  /// Uses the resolved profile table name and ignores errors if the column is
  /// missing or RLS prevents the write.
  static Future<void> setGuardianIdForAssisted(
    SupabaseClient client, {
    required String assistedUserId,
    required String guardianUserId,
  }) async {
    try {
      final table = await _resolveTable(client);
      await client
          .from(table)
          .update({'guardian_id': guardianUserId})
          .eq('id', assistedUserId);
    } catch (_) {
      // ignore
    }
  }
}

/// Result payload returned after uploading an avatar image.
class AvatarUploadResult {
  AvatarUploadResult({required this.path, required this.publicUrl});

  final String path;
  final String publicUrl;
}
