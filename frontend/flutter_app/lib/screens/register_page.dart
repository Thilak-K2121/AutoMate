import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedGender = 'Male'; // Default value
  final List<String> _genders = ['Male', 'Female', 'Other'];

  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (!email.endsWith('@bmsce.ac.in')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please use your college email (@bmsce.ac.in)")),
      );
      return;
    }

    // 📱 Phone Validation: Numeric only & Minimum 10 digits
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number must contain only numbers")),
      );
      return;
    }

    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number must have at least 10 digits")),
      );
      return;
    }

    if (phone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number cannot exceed 15 digits")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters long")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.postRequest('/auth/register', {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'gender': _selectedGender, // <-- NEW: Passing gender to backend
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await ApiService.saveToken(data['token']);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? "Registration failed"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Network error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(
                title: "Create your account",
                subtitle:
                    "Join verified BMSCE students sharing rides every day.",
              ),

              const SizedBox(height: 28),

              AppTextField(
                controller: _nameController,
                label: "Full name",
                hint: "e.g. Alex Johnson",
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              AppTextField(
                controller: _emailController,
                label: "College email",
                hint: "you@bmsce.ac.in",
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              AppTextField(
                controller: _phoneController,
                label: "Phone number",
                hint: "e.g. 9876543210",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
              ),
              const SizedBox(height: 18),

              AppTextField(
                controller: _passwordController,
                label: "Password",
                hint: "At least 6 characters",
                icon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 18),

              /// Gender — segmented selector
              const Text(
                "Gender",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: _genders.map((gender) {
                    final selected = gender == _selectedGender;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = gender),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.surface
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm + 2),
                            boxShadow: selected ? AppShadows.card : null,
                          ),
                          child: Text(
                            gender,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected
                                  ? AppColors.ink
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Used only to enable women-only rides.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),

              const SizedBox(height: 28),

              PrimaryButton(
                label: "Create account",
                icon: Icons.arrow_forward_rounded,
                loading: _isLoading,
                onPressed: _handleRegister,
              ),

              const SizedBox(height: 20),

              const Center(child: VerifiedBadge()),

              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text.rich(
                    TextSpan(
                      text: "Already have an account?  ",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: "Sign in",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
