import 'package:supabase_flutter/supabase_flutter.dart';

/// Service enabling multiple guardians per assisted via a join table.
/// Expected table: public.assisted_guardians(assisted_id uuid, guardian_id uuid, created_at timestamptz default now())
class MultiGuardianService {
  MultiGuardianService._();

  static final List<String> _profileCandidates = const [
    'profile',
    'profiles',
    'profile table',
    'profile_table',
  ];

  static Future<String> _resolveProfileTable(SupabaseClient client) async {
    for (final name in _profileCandidates) {
      try {
        await client.from(name).select('id').limit(1).maybeSingle();
        return name;
      } catch (_) {
        continue;
      }
    }
    return 'profile';
  }

  /// List guardian IDs for an assisted; merges join table + legacy guardian_id.
  /// Returns a unique set of auth user IDs for guardians. Avoids selecting
  /// guardian profiles to reduce RLS friction when only IDs are needed.
  static Future<Set<String>> listGuardianIds(
    SupabaseClient client, {
    String? assistedUserId,
  }) async {
    final assistedId = assistedUserId ?? client.auth.currentUser?.id;
    if (assistedId == null) return <String>{};
    final Set<String> idSet = <String>{};

    // 1) Read join table links if available
    try {
      final links = await client
          .from('assisted_guardians')
          .select('guardian_id')
          .eq('assisted_id', assistedId);
      for (final e in links as List) {
        final v = e['guardian_id']?.toString();
        if (v != null && v.isNotEmpty) idSet.add(v);
      }
    } catch (_) {
      // table missing or RLS blocked; continue with legacy
    }

    // 2) Also include legacy single guardian from own profile.guardian_id
    try {
      final profileTable = await _resolveProfileTable(client);
      final me = await client
          .from(profileTable)
          .select('guardian_id')
          .eq('id', assistedId)
          .maybeSingle();
      final gid = me?['guardian_id']?.toString();
      if (gid != null && gid.isNotEmpty) idSet.add(gid);
    } catch (_) {}

    return idSet;
  }

  /// Find guardian auth user id by their public_id in the profile table.
  static Future<String?> _guardianIdByPublicId(
    SupabaseClient client, {
    required String publicId,
  }) async {
    final table = await _resolveProfileTable(client);
    try {
      final row = await client
          .from(table)
          .select('id')
          .eq('public_id', publicId)
          .maybeSingle();
      return row == null ? null : (row['id'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Add guardian via public id into assisted_guardians.
  /// Returns true on success.
  static Future<bool> addGuardianByPublicId(
    SupabaseClient client, {
    required String guardianPublicId,
    String? assistedUserId,
  }) async {
    final assistedId = assistedUserId ?? client.auth.currentUser?.id;
    if (assistedId == null) return false;
    final gid = await _guardianIdByPublicId(client, publicId: guardianPublicId);
    if (gid == null) return false;

    try {
      await client
          .from('assisted_guardians')
          .insert({'assisted_id': assistedId, 'guardian_id': gid});
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final relMissing = msg.contains('assisted_guardians') &&
          (msg.contains('relation') || msg.contains('does not exist'));
      if (relMissing) {
        // Join table missing; signal caller so they can prompt for DB setup.
        return false;
      }
      // Duplicate or other issues: treat duplicate as success to be idempotent
      if (msg.contains('duplicate') || msg.contains('unique')) return true;
      return false;
    }
  }

  /// Remove guardian link.
  static Future<bool> removeGuardian(
    SupabaseClient client, {
    required String guardianId,
    String? assistedUserId,
  }) async {
    final assistedId = assistedUserId ?? client.auth.currentUser?.id;
    if (assistedId == null) return false;
    try {
      final List res = await client
          .from('assisted_guardians')
          .delete()
          .eq('assisted_id', assistedId)
          .eq('guardian_id', guardianId)
          .select('guardian_id');
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// List guardians for an assisted; returns profile rows (id, fullname, email, public_id).
  static Future<List<Map<String, dynamic>>> listGuardians(
    SupabaseClient client, {
    String? assistedUserId,
  }) async {
    final assistedId = assistedUserId ?? client.auth.currentUser?.id;
    if (assistedId == null) return [];
    final profileTable = await _resolveProfileTable(client);
    try {
      // 1) Collect from join table
      final Set<String> idSet = <String>{};
      try {
        final links = await client
            .from('assisted_guardians')
            .select('guardian_id')
            .eq('assisted_id', assistedId);
        for (final e in links) {
          final v = e['guardian_id']?.toString();
          if (v != null && v.isNotEmpty) idSet.add(v);
        }
      } catch (_) {
        // join table may be missing; proceed to fallback
      }

      // 2) Also include legacy single guardian from profile.guardian_id if present
      try {
        final me = await client
            .from(profileTable)
            .select('guardian_id')
            .eq('id', assistedId)
            .maybeSingle();
        final gid = me?['guardian_id']?.toString();
        if (gid != null && gid.isNotEmpty) idSet.add(gid);
      } catch (_) {}

      if (idSet.isEmpty) return [];
    final rows = await client
      .from(profileTable)
      .select('id, fullname, email, public_id, avatar_url')
      .inFilter('id', idSet.toList());
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      // If join table missing, gracefully return empty to allow UI to hint setup
      return [];
    }
  }
}
