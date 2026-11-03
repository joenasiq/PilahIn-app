import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _register() {
    setState(() => _errorMessage = null);

    // Validasi form: jika ada field tidak valid, pendaftaran dibatalkan.
    if (!_formKey.currentState!.validate()) return;

    ref
        .read(authControllerProvider.notifier)
        .register(
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AsyncError) {
        final errorMsg = next.error.toString().replaceAll('Exception: ', '');
        setState(() => _errorMessage = errorMsg);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final authState = ref.watch(authControllerProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Daftar Akun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buat akun untuk mulai memilah sampah',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _nameController,
                            labelText: 'Nama',
                            hintText: 'Masukkan nama Anda',
                            onChanged: (_) => _clearError(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const Divider(height: 32, thickness: 1),
                          AppTextField(
                            controller: _emailController,
                            labelText: 'Email',
                            hintText: 'Masukkan email Anda',
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => _clearError(),
                            validator: validateEmail,
                          ),
                          const Divider(height: 32, thickness: 1),
                          AppTextField(
                            controller: _passwordController,
                            labelText: 'Kata Sandi',
                            hintText: 'Minimal 8 karakter',
                            obscureText: _obscurePassword,
                            onChanged: (_) => _clearError(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textGrey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: validatePassword,
                          ),
                          const Divider(height: 32, thickness: 1),
                          AppTextField(
                            controller: _confirmPasswordController,
                            labelText: 'Konfirmasi Kata Sandi',
                            hintText: 'Ulangi kata sandi Anda',
                            obscureText: _obscureConfirmation,
                            onChanged: (_) => _clearError(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textGrey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmation = !_obscureConfirmation;
                                });
                              },
                            ),
                            validator: (value) => validatePasswordConfirmation(
                              value,
                              _passwordController.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pesan error dari proses pendaftaran (mis. email terdaftar)
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  PrimaryButton(
                    text: 'Daftar',
                    isLoading: authState.isLoading,
                    onPressed: _register,
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sudah punya akun?',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                        TextButton(
                          onPressed: authState.isLoading
                              ? null
                              : () => context.go('/login'),
                          child: const Text('Masuk'),
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
  }
}
