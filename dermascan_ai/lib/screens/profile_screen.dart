import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';

/// Profile screen with user info, interactive editing, and settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _allergiesController;

  String? _selectedSkinType;
  String? _photoUrl;

  final List<String> _skinTypes = [
    'Fitzpatrick I',
    'Fitzpatrick II',
    'Fitzpatrick III',
    'Fitzpatrick IV',
    'Fitzpatrick V',
    'Fitzpatrick VI',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _allergiesController = TextEditingController();
    
    // Defer initialization to after build context is active
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFields());
  }

  void _initFields() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      setState(() {
        _nameController.text = user.name ?? '';
        _ageController.text = user.age?.toString() ?? '';
        _allergiesController.text = user.allergies?.join(', ') ?? '';
        _selectedSkinType = user.skinType;
        _photoUrl = user.photoUrl;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Choose Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1B3A5C)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A9396).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0A9396)),
              ),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Use your camera', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3A5C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF1B3A5C)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick an existing photo', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 75,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user != null) {
      final allergiesList = _allergiesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedUser = user.copyWith(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        allergies: allergiesList,
        skinType: _selectedSkinType,
        photoUrl: _photoUrl,
      );

      await auth.updateProfile(updatedUser);
      
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        _showSnackBar('Profile updated successfully!');
      }
    } else {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext ctx, AuthProvider auth) async {
    final passCtrl = TextEditingController();
    bool obscure = true;
    bool dialogLoading = false;

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: AppColors.danger, size: 22),
              SizedBox(width: 10),
              Text('Delete Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.danger)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your account and ALL your scan history. This cannot be undone.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text('Enter your password to confirm:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.danger, width: 2)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textTertiary),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: dialogLoading
                  ? null
                  : () async {
                      final password = passCtrl.text.trim();
                      if (password.isEmpty) return;
                      
                      setDialogState(() => dialogLoading = true);
                      final ok = await auth.deleteAccount(password: password);
                      
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }
                      
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (_) => false);
                      } else {
                        _showSnackBar(auth.error ?? 'Failed to delete account', isError: true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: dialogLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    passCtrl.dispose();
  }

  Widget _buildAvatar(String? photoUrl, String displayName, {double radius = 44}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final base64Content = photoUrl.split(',').last;
          final bytes = base64Decode(base64Content);
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (e) {
          // Fallback
        }
      } else {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(photoUrl),
        );
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          AppStrings.profile,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // No back arrow — inside IndexedStack
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              onPressed: () {
                _initFields(); // reload latest details
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.danger),
              onPressed: () {
                _initFields(); // discard changes
                setState(() {
                  _isEditing = false;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.success),
              onPressed: _saveProfile,
            ),
          ]
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final displayName = user.displayName ?? 'User';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Avatar Picker ──
                  GestureDetector(
                    onTap: _isEditing ? _pickImage : null,
                    child: Stack(
                      children: [
                        _buildAvatar(_photoUrl, displayName, radius: 48),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── User Name & Email Displays ──
                  if (!_isEditing) ...[
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? user?.phone ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Enter name',
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 32),

                  // ── Medical Information Section ──
                  _SectionCard(
                    title: 'Medical Information',
                    children: [
                      // Skin Type Row
                      _isEditing
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: DropdownButtonFormField<String>(
                                value: _selectedSkinType,
                                items: _skinTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSkinType = val;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: AppStrings.skinType,
                                  border: UnderlineInputBorder(),
                                ),
                              ),
                            )
                          : _InfoRow(
                              icon: Icons.face_rounded,
                              label: AppStrings.skinType,
                              value: user?.skinType ?? 'Not set',
                            ),

                      // Age Row
                      _isEditing
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Age',
                                  border: UnderlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final val = int.tryParse(value);
                                    if (val == null || val < 1 || val > 120) {
                                      return 'Please enter a valid age';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            )
                          : _InfoRow(
                              icon: Icons.cake_rounded,
                              label: 'Age',
                              value: user?.age?.toString() ?? 'Not set',
                            ),

                      // Allergies Row
                      _isEditing
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: TextFormField(
                                controller: _allergiesController,
                                decoration: const InputDecoration(
                                  labelText: 'Allergies (comma separated)',
                                  border: UnderlineInputBorder(),
                                  hintText: 'e.g., Peanuts, Penicillin',
                                ),
                              ),
                            )
                          : _InfoRow(
                              icon: Icons.warning_amber_rounded,
                              label: 'Allergies',
                              value: user?.allergies != null && user!.allergies!.isNotEmpty
                                  ? user.allergies!.join(', ')
                                  : 'None',
                            ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Settings Section ──
                  if (!_isEditing) ...[
                    _SectionCard(
                      title: 'Settings',
                      children: [
                        _SettingRow(
                          icon: Icons.notifications_rounded,
                          label: AppStrings.notifications,
                          onTap: () {},
                        ),
                        _SettingRow(
                          icon: Icons.info_outline_rounded,
                          label: AppStrings.aboutApp,
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: AppStrings.appName,
                              applicationVersion: '1.0.0',
                              applicationLegalese: AppStrings.medicalDisclaimer,
                            );
                          },
                        ),
                        _SettingRow(
                          icon: Icons.privacy_tip_outlined,
                          label: AppStrings.privacyPolicy,
                          onTap: () {},
                        ),
                        _SettingRow(
                          icon: Icons.description_outlined,
                          label: AppStrings.termsOfService,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                        label: const Text(
                          AppStrings.logout,
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Delete Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton.icon(
                        onPressed: () => _showDeleteAccountDialog(context, auth),
                        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFF6B7280), size: 20),
                        label: const Text(
                          'Delete Account',
                          style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
