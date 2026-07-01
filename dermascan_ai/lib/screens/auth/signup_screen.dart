import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';

/// Signup screen for DermaScan AI application
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedSkinType;
  String? _profilePhotoBase64;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _pickProfilePhoto() async {
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
              width: 40, height: 4,
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
          _profilePhotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  // Fitzpatrick Skin Types with corresponding color values for visual guidance
  final List<Map<String, dynamic>> _skinTypes = [
    {'label': 'Fitzpatrick I', 'value': 'Fitzpatrick I', 'color': Color(0xFFF9D5C3)},
    {'label': 'Fitzpatrick II', 'value': 'Fitzpatrick II', 'color': Color(0xFFF1C2A7)},
    {'label': 'Fitzpatrick III', 'value': 'Fitzpatrick III', 'color': Color(0xFFE0AC8D)},
    {'label': 'Fitzpatrick IV', 'value': 'Fitzpatrick IV', 'color': Color(0xFFC68A64)},
    {'label': 'Fitzpatrick V', 'value': 'Fitzpatrick V', 'color': Color(0xFF985B38)},
    {'label': 'Fitzpatrick VI', 'value': 'Fitzpatrick VI', 'color': Color(0xFF5A3825)},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 0;

    // Firebase requires an email address. If none is provided, generate a fallback.
    final finalEmail = email.isNotEmpty ? email : '$phone@dermascan.com';

    try {
      // Step 1: Create email/password account
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: finalEmail, password: password);

      // Send verification email immediately ONLY if registering with a real email address
      if (email.isNotEmpty) {
        await userCredential.user?.sendEmailVerification();
      }

      final uid = userCredential.user?.uid;
      if (uid != null) {
        // Step 2: Save user profile data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'phone': phone,
          'email': email,
          'photoUrl': _profilePhotoBase64,
          'skinType': _selectedSkinType,
          'age': age,
          'phoneVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        await context.read<AuthProvider>().initialize();
        if (mounted) {
          // Go to email verification — user must click the link before using the app
          Navigator.pushReplacementNamed(context, '/verify-email', arguments: email);
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'An error occurred during sign up.');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError('An unexpected error occurred: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Modern input field decorator
  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary.withOpacity(0.7), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF0F4F8);
    const primaryColor = Color(0xFF1B3A5C);
    const accentColor = Color(0xFF0A9396);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ── Beautiful Background Gradients ──
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(0.12),
                    accentColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.08),
                    primaryColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // 1. Profile Photo Picker / Logo
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.08),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              image: _profilePhotoBase64 != null
                                  ? DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(_profilePhotoBase64!.split(',').last),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profilePhotoBase64 == null
                                ? const Icon(
                                    Icons.person_outline_rounded,
                                    color: accentColor,
                                    size: 44,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: accentColor,
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
                    const SizedBox(height: 12),
                    const Text(
                      'DermaScan AI',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 2. Tagline
                    const Text(
                      'AI-powered skin health assistant',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 3. White card container
                    Card(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: primaryColor.withOpacity(0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 4. Inside card components
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Full Name field
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                if (v.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone Number field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (v.trim().length < 10) {
                                  return 'Phone number must be at least 10 digits';
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration(
                                labelText: 'Email Address (Optional)',
                                prefixIcon: Icons.email_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (v.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: primaryColor.withOpacity(0.6),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: primaryColor.withOpacity(0.6),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Skin Type label
                            const Text(
                              'Select Your Fitzpatrick Skin Type',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Interactive Color Grid/Row for Skin Type (replaces standard clunky Dropdown)
                            Container(
                              height: 64,
                              child: FormField<String>(
                                validator: (value) => _selectedSkinType == null ? 'Please select a skin type' : null,
                                builder: (FormFieldState<String> state) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: _skinTypes.length,
                                          itemBuilder: (context, idx) {
                                            final item = _skinTypes[idx];
                                            final isSelected = _selectedSkinType == item['value'];
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedSkinType = item['value'];
                                                });
                                                state.didChange(item['value']);
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.only(right: 10),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? accentColor.withOpacity(0.08) : const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected ? accentColor : Colors.grey.shade200,
                                                    width: isSelected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: item['color'] as Color,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: Colors.white, width: 1.5),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.08),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      item['label']!.toString().split(' ').last,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                        color: isSelected ? accentColor : primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (state.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, left: 4),
                                          child: Text(
                                            state.errorText ?? '',
                                            style: const TextStyle(color: AppColors.danger, fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Age field
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your age';
                                }
                                final val = int.tryParse(v.trim());
                                if (val == null || val < 1 || val > 120) {
                                  return 'Please enter a valid age between 1 and 120';
                                }
                                return null;
                              },
                              decoration: _buildInputDecoration(
                                labelText: 'Age',
                                prefixIcon: Icons.calendar_today_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Medical disclaimer text
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'By signing up you agree this app is for educational use only and not a substitute for medical advice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6. Create Account button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 9. Bottom switch text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
