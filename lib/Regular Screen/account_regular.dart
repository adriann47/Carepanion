import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:softeng/data/profile_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? email; // ← from Supabase Auth
  String mobile = ""; // empty by default
  List<String> guardians = [];

  final TextEditingController _currentPass = TextEditingController();
  final TextEditingController _newPass = TextEditingController();
  final TextEditingController _confirmPass = TextEditingController();
  bool _savingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _signOutAll = false;

  @override
  void initState() {
    super.initState();
    _loadAuthEmail();
    _loadPhone();
  }

  void _loadAuthEmail() {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      email = user?.email ?? '—';
    });
  }

  Future<void> _loadPhone() async {
    try {
      final data = await ProfileService.fetchProfile(Supabase.instance.client);
      if (!mounted) return;
      final p = ProfileService.readPhoneFrom(data) ?? '';
      setState(() => mobile = p);
    } catch (_) {}
  }

  // Edit Field Dialog (used for mobile and guardians)
  void _editField(String title, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter new $title",
            border: const OutlineInputBorder(),
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
                      SnackBar(content: Text(ok ? 'Mobile updated' : 'Saved locally; server column missing')), 
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

  // Add Guardian Dialog
  void _addGuardian() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Guardian"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter guardian name or email",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  guardians.add(controller.text.trim());
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // Read-only Row (for Email)
  Widget _buildReadOnlyRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
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

  // Editable Row (Mobile)
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
        color: const Color(0x99B3E5FC), // 60% opacity of light blue
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          suffixIcon: IconButton(
            tooltip: obscure ? 'Show password' : 'Hide password',
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSavePassword() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to change password.')),
      );
      return;
    }

    // Disallow for Google-only accounts
    try {
      final provider = user.appMetadata['provider']?.toString();
      if ((provider ?? '').toLowerCase() == 'google') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password change isn't available for Google sign-in accounts.")),
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
    // Match registration rules
    if (!RegExp(r'[A-Z]').hasMatch(newPass)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Must contain 1 uppercase letter')),
      );
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(newPass)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Must contain 1 number')),
      );
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
      // Re-authenticate for email accounts only
      if ((user.email ?? '').isNotEmpty) {
        try {
          await client.auth.signInWithPassword(email: user.email!, password: current);
        } on AuthException catch (e) {
          if (!mounted) return;
          final msg = e.message.toLowerCase();
          final friendly = msg.contains('invalid')
              ? 'Current password is incorrect.'
              : 'Failed to verify current password.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendly)),
          );
          return;
        }
      }

      final res = await client.auth.updateUser(UserAttributes(password: newPass));
      if (res.user == null) throw Exception('Password update failed.');

      if (!mounted) return;
      _currentPass.clear();
      _newPass.clear();
      _confirmPass.clear();
      if (_signOutAll) {
        try {
          await client.auth.signOut(scope: SignOutScope.global);
        } catch (_) {
          await client.auth.signOut();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. Signed out of all devices.')),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        }
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Widget _buildGuardianRow(String guardian) {
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
          Text(
            guardian,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                guardians.remove(guardian);
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPass.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
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
          // 🔹 Header
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
                padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF3D3D3D)),
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

          // 🔹 Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: w * 0.08, vertical: h * 0.025),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EMAIL: read-only from Supabase Auth
                  _buildReadOnlyRow("Email", email ?? '—'),

                  // MOBILE: editable
                  _buildEditableRow("Mobile Number", mobile.isEmpty ? '—' : mobile, () {
                    _editField("Mobile Number", mobile, (val) {
                      setState(() => mobile = val);
                    });
                  }),

                  SizedBox(height: h * 0.03),

                  // 🔹 Reset Password Section
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
                    onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
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
                    onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),

                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: _signOutAll,
                    onChanged: (v) => setState(() => _signOutAll = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Sign out of all devices after saving',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),

                  Center(
                    child: ElevatedButton(
                      onPressed: _savingPassword ? null : _handleSavePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0x99B3E5FC),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: _savingPassword
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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

                  const Divider(color: Colors.black26, thickness: 1, indent: 10, endIndent: 10),

                  SizedBox(height: h * 0.02),

                  // 🔹 Guardian Section
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

                  ...guardians.map((g) => _buildGuardianRow(g)),

                  GestureDetector(
                    onTap: _addGuardian,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
