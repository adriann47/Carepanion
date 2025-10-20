import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/multi_guardian_service.dart';
import 'package:softeng/data/profile_service.dart';
import '../services/navigation.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String email = "";
  String mobile = "";
  List<Map<String, dynamic>> guardians = [];
  bool _loadingGuardians = false;
  bool _savingPassword = false;
  bool _signOutAll = false;
  RealtimeChannel? _agChannel;
  RealtimeChannel? _profileChannel;

  final TextEditingController _currentPass = TextEditingController();
  final TextEditingController _newPass = TextEditingController();
  final TextEditingController _confirmPass = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Edit Field Dialog (still used for other editable items if needed)
  // ignore: unused_element
  void _editField(String title, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter new value",
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
              final newVal = controller.text.trim();
              if (newVal.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              if (title.toLowerCase().contains('mobile')) {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null) {
                  final ok = await ProfileService.setPhone(
                    Supabase.instance.client,
                    id: userId,
                    phone: newVal,
                  );
                  if (mounted) {
                    setState(() => mobile = newVal);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Mobile updated'
                              : 'Saved locally; server column missing',
                        ),
                      ),
                    );
                  }
                }
              } else {
                onSave(newVal);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadPhone();
    _subscribeRealtime();
  }

  Future<void> _loadPhone() async {
    try {
      final data = await ProfileService.fetchProfile(Supabase.instance.client);
      if (!mounted) return;
      final p = ProfileService.readPhoneFrom(data) ?? '';
      setState(() => mobile = p);
    } catch (_) {}
  }

  Future<void> _handleSavePassword() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to change password.'),
        ),
      );
      return;
    }

    // Disallow for Google-only accounts (no existing password)
    try {
      final provider = user.appMetadata['provider']?.toString();
      if ((provider ?? '').toLowerCase() == 'google') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Password change isn't available for Google sign-in accounts.",
            ),
          ),
        );
        return;
      }
    } catch (_) {}

    final current = _currentPass.text.trim();
    final newPass = _newPass.text.trim();
    final confirm = _confirmPass.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }
    if (newPass != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }
    // Match registration requirements: at least 1 uppercase, 1 digit, 1 special
    if (!RegExp(r'[A-Z]').hasMatch(newPass)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Must contain 1 uppercase letter')),
      );
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(newPass)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Must contain 1 number')));
      return;
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(newPass)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Must contain 1 special character')),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      // Optional re-authenticate to verify current password (email accounts only)
      if ((user.email ?? '').isNotEmpty) {
        try {
          await client.auth.signInWithPassword(
            email: user.email!,
            password: current,
          );
        } on AuthException catch (e) {
          if (!mounted) return;
          final msg = e.message.toLowerCase();
          final friendly = msg.contains('invalid')
              ? 'Current password is incorrect.'
              : 'Failed to verify current password.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendly)));
          return;
        }
      }

      // Update password
      final res = await client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (res.user == null) {
        throw Exception('Password update failed.');
      }

      if (!mounted) return;
      _currentPass.clear();
      _newPass.clear();
      _confirmPass.clear();
      if (_signOutAll) {
        // Revoke sessions on all devices (including current) and take user to sign-in
        try {
          await client.auth.signOut(scope: SignOutScope.global);
        } catch (_) {
          // Fallback: local sign out if scope not supported
          await client.auth.signOut();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated. Signed out of all devices.'),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/signin', (route) => false);
        }
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update password: $e')));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
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
        event: PostgresChangeEvent.update,
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

  @override
  void dispose() {
    _agChannel?.unsubscribe();
    _profileChannel?.unsubscribe();
    _currentPass.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
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
                final supabase = Supabase.instance.client;
                if (!mounted) return;

                // Resolve a robust context using the global navigator's overlay, falling back to page context
                BuildContext waitContext =
                    navKey.currentState?.overlay?.context ??
                        navKey.currentContext ??
                        context;

                // Show the waiting dialog FIRST at the root navigator to avoid any race with closing the input dialog
                showDialog<void>(
                  context: waitContext,
                  barrierDismissible: false,
                  useRootNavigator: true,
                  builder: (waitCtx) => PopScope(
                    canPop: false,
                    child: Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      backgroundColor: Colors.white,
                      child: SingleChildScrollView(
                        child: Container(
                          width: 320,
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'WAITING FOR GUARDIAN',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF4A4A4A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC68A),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: const Color(0xFFCA5000),
                                    width: 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      offset: const Offset(0, 4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'REQUEST SENT',
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF5A2F00),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'A request has been sent to your guardian. Waiting for confirmation...',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2B2B2B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFCA5000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                // Let the dialog mount, then close the input prompt behind it
                await Future.delayed(const Duration(milliseconds: 50));
                try { Navigator.pop(ctx); } catch (_) {}

                // Now create or re-use the pending guardian request
                final req = await ProfileService.requestGuardianByPublicId(
                  supabase,
                  guardianPublicId: code,
                );
                final guardianId = req['guardianId'] ?? '';

                // Wait for response up to 5 minutes (filtered to this guardian)
                var status = req['status'] ?? 'pending';
                if (status != 'accepted' && status != 'rejected') {
                  status = await ProfileService.waitForGuardianResponse(
                    supabase,
                    guardianUserId: guardianId,
                    timeout: const Duration(minutes: 5),
                  );
                }
                if (!mounted) return;
                // Close waiting dialog
                try {
                  Navigator.of(waitContext, rootNavigator: true).pop();
                } catch (_) {}

                if (status == 'accepted') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guardian accepted.')),
                  );
                  await _refreshGuardians();
                } else if (status == 'rejected') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Guardian rejected your request.'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No response from guardian (timeout).'),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                // Close waiting dialog if it is showing
                try {
                  final wc = navKey.currentState?.overlay?.context ?? context;
                  Navigator.of(wc, rootNavigator: true).pop();
                } catch (_) {}
                // Also ensure input dialog is closed
                try { Navigator.pop(ctx); } catch (_) {}
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to request guardian: $e')),
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

  // Editable Row (Mobile) — same look as Regular account
  Widget _buildEditableRow(String label, String value, VoidCallback onEdit) {
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
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // TextField for Reset Password (with lower opacity)
  Widget _buildPasswordField(
    String hint,
    TextEditingController controller, {
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x99B3E5FC),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
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
          suffixIcon: IconButton(
            tooltip: obscure ? 'Show password' : 'Hide password',
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
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
            decoration: const BoxDecoration(
              color: Color(0xFFF7A9AC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: w * 0.05,
                right: w * 0.05,
                bottom: 16,
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.08,
                vertical: h * 0.02,
              ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email (read-only)
                  _buildReadOnlyRow("Email", email),

                  // MOBILE: editable (empty by default)
                  _buildEditableRow(
                    "Mobile Number",
                    mobile.isEmpty ? '' : mobile,
                    () {
                      _editField("Mobile Number", mobile, (val) async {
                        setState(() => mobile = val);
                      });
                    },
                  ),

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
                  _buildPasswordField(
                    "CURRENT PASSWORD",
                    _currentPass,
                    obscure: _obscureCurrent,
                    onToggle: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  _buildPasswordField(
                    "NEW PASSWORD",
                    _newPass,
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  _buildPasswordField(
                    "CONFIRM NEW PASSWORD",
                    _confirmPass,
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),

                  // Sign out everywhere option
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: _signOutAll,
                    onChanged: (v) => setState(() => _signOutAll = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Sign out of all devices after saving',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Center(
                    child: ElevatedButton(
                      onPressed: _savingPassword ? null : _handleSavePassword,
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
                      child: _savingPassword
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
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
}
