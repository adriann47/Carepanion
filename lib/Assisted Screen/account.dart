import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/multi_guardian_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String email = "";
  List<Map<String, dynamic>> guardians = [];
  bool _loadingGuardians = false;
  RealtimeChannel? _agChannel;
  RealtimeChannel? _profileChannel;

  final TextEditingController _currentPass = TextEditingController();
  final TextEditingController _newPass = TextEditingController();
  final TextEditingController _confirmPass = TextEditingController();

  // Edit Field Dialog (still used for other editable items if needed)

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _subscribeRealtime();
  }

  Future<void> _loadInitial() async {
    // Try to get email and guardians
    try {
      final user = Supabase.instance.client.auth.currentUser;
      setState(() {
        email = user?.email ?? '';
      });
    } catch (_) {}
    await _refreshGuardians();
  }

  Future<void> _refreshGuardians() async {
    setState(() => _loadingGuardians = true);
    try {
      final rows = await MultiGuardianService.listGuardians(
        Supabase.instance.client,
      );
      if (!mounted) return;
      setState(() => guardians = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => guardians = []);
    } finally {
      if (mounted) setState(() => _loadingGuardians = false);
    }
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    // Subscribe to assisted_guardians insert/delete for this assisted user
    _agChannel?.unsubscribe();
    _agChannel = client.channel('public:assisted_guardians:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) {
          final newRec = payload.newRecord as Map<String, dynamic>?;
          if (newRec?['assisted_id']?.toString() == uid) {
            _refreshGuardians();
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'assisted_guardians',
        callback: (payload) {
          final oldRec = payload.oldRecord as Map<String, dynamic>?;
          if (oldRec?['assisted_id']?.toString() == uid) {
            _refreshGuardians();
          }
        },
      )
      ..subscribe();

    // Subscribe to legacy profile guardian_id updates for current assisted
    _profileChannel?.unsubscribe();
    _profileChannel = client.channel('public:profile_guardian:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profile',
        callback: (payload) {
          final newRec = payload.newRecord as Map<String, dynamic>?;
          if (newRec?['id']?.toString() == uid) {
            _refreshGuardians();
          }
        },
      )
      ..subscribe();
  }

  // Add Guardian Dialog (updated hint text ✅)
  void _addGuardian() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Guardian"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter guardian id", // ✅ changed here
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              try {
                final ok = await MultiGuardianService.addGuardianByPublicId(
                  Supabase.instance.client,
                  guardianPublicId: code,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guardian linked')),
                  );
                  await _refreshGuardians();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to link guardian. Ensure table and code are correct.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to link guardian: $e')),
                );
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // Read-only row (for Email)
  Widget _buildReadOnlyRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TextField for Reset Password (with lower opacity)
  Widget _buildPasswordField(String hint, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x99B3E5FC),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(
            color: Colors.black.withOpacity(0.4),
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: const Color(0x66B3E5FC),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGuardianRow(Map<String, dynamic> guardian) {
    final name = (guardian['fullname'] ?? '').toString().trim();
    final pub = (guardian['public_id'] ?? '').toString().trim();
    final gid = (guardian['id'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : '(No name)',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (pub.isNotEmpty)
                  Text(
                    'ID: $pub',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              try {
                final ok = await MultiGuardianService.removeGuardian(
                  Supabase.instance.client,
                  guardianId: gid,
                );
                if (!mounted) return;
                if (ok) {
                  await _refreshGuardians();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guardian unlinked')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to unlink guardian')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF5F0),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            height: h * 0.18,
            decoration: const BoxDecoration(
              color: Color(0xFFF7A9AC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.05,
                  vertical: h * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF3D3D3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ACCOUNT",
                      style: GoogleFonts.nunito(
                        fontSize: w * 0.07,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3D3D3D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.08,
                vertical: h * 0.025,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email (read-only)
                  _buildReadOnlyRow("Email", email),

                  SizedBox(height: h * 0.03),

                  // Reset Password
                  Center(
                    child: Text(
                      "RESET PASSWORD",
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPasswordField("CURRENT PASSWORD", _currentPass),
                  _buildPasswordField("NEW PASSWORD", _newPass),
                  _buildPasswordField("CONFIRM NEW PASSWORD", _confirmPass),

                  Center(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0x99B3E5FC),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "SAVE",
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: h * 0.03),

                  const Divider(
                    color: Colors.black26,
                    thickness: 1,
                    indent: 10,
                    endIndent: 10,
                  ),

                  SizedBox(height: h * 0.02),

                  // Guardian Section
                  Center(
                    child: Text(
                      "GUARDIAN’S ACCOUNT",
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_loadingGuardians)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ...guardians.map((g) => _buildGuardianRow(g)),

                  GestureDetector(
                    onTap: _addGuardian,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3E5FC),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ADD A GUARDIAN",
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const Icon(Icons.add, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _agChannel?.unsubscribe();
    _profileChannel?.unsubscribe();
    super.dispose();
  }
}
