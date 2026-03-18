
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (!email.endsWith('@bmsce.ac.in')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please use your college email")),
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
          SnackBar(content: Text(errorData['message'] ?? "Registration failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _inputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? type,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: type,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
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
      backgroundColor: const Color(0xFFEFF4F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  /// Logo
                  Image.asset(
                    "assets/images/auto_icon.png",
                    width: 120,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3A4B),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Join AutoMate today",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _inputField(_nameController, "e.g. Alex Johnson", Icons.person),
                        const SizedBox(height: 16),

                        _inputField(_emailController, "e.g. student@bmsce.ac.in", Icons.mail_outline),
                        const SizedBox(height: 16),

                        _inputField(_phoneController, "e.g. 9876543210", Icons.phone_outlined),
                        const SizedBox(height: 16),

                        _inputField(_passwordController, "Enter password", Icons.lock_outline, obscure: true),
                        const SizedBox(height: 24),

                        /// Register button
                        GestureDetector(
                          onTap: _isLoading ? null : _handleRegister,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF34C759), Color(0xFF28A745)],
                              ),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      "Register",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// Divider
                        Row(
                          children: [
                            Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text("or", style: TextStyle(color: Color(0xFF9CA3AF))),
                            ),
                            Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
                          ],
                        ),

                        const SizedBox(height: 16),

                        /// Google button (FIXED)
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Google Sign Up coming soon 🚀")),
                            );
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/images/google.png",
                                  width: 22,
                                  height: 22,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Sign up with Google",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// Back to login
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Already have an account? Sign In",
                            style: TextStyle(
                              color: Color(0xFF28A745),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
