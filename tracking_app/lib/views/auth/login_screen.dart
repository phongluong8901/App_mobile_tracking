import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../theme/app_design_tokens.dart';
import 'change_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final settings = AppSettingsService.instance;
    if (settings.hasLinkedBiometrics) {
      _emailController.text = settings.linkedBiometricEmail ?? '';
    }
    // Tự động mở hộp thoại sinh trắc học hệ thống khi mở app nếu người dùng đã bật
    if (settings.autoBiometricPrompt &&
        settings.hasLinkedBiometrics &&
        settings.biometricLoginEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handleSystemBiometricLogin();
        });
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = AuthService.instance;
    final res = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (res.success) {
      // Tự động lưu ủy quyền sinh trắc học nếu chưa lưu
      final settings = AppSettingsService.instance;
      if (!settings.hasLinkedBiometrics) {
        settings.linkBiometricCredentials(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppDesignTokens.successEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      widget.onLoginSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppDesignTokens.dangerRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  /// XÁC THỰC SINH TRẮC HỌC HỆ THỐNG CHUẨN (ANDROID BIOMETRIC PROMPT - DÙNG CHUNG CẢ VÂN TAY VÀ KHUÔN MẶT)
  Future<void> _handleSystemBiometricLogin() async {
    final settings = AppSettingsService.instance;
    if (!settings.biometricLoginEnabled && !settings.faceLoginEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tính năng đăng nhập sinh trắc học đang bị tắt trong Cài Đặt!',
          ),
          backgroundColor: AppDesignTokens.warningAmber,
        ),
      );
      return;
    }

    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : settings.linkedBiometricEmail;
    final pass = _passwordController.text.isNotEmpty
        ? _passwordController.text
        : settings.linkedBiometricPassword;

    if (email == null || email.isEmpty || pass == null || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng đăng nhập 1 lần bằng Email & Mật khẩu để liên kết sinh trắc học hệ thống!',
          ),
          backgroundColor: AppDesignTokens.warningAmber,
        ),
      );
      return;
    }

    final bio = BiometricAuthService.instance;
    final res = await bio.authenticateWithSystemBiometrics(
      reason: 'Quét vân tay hoặc khuôn mặt hệ thống để đăng nhập',
    );

    if (!mounted) return;

    if (res.success) {
      final auth = AuthService.instance;
      final signRes = await auth.signIn(email: email, password: pass);
      if (mounted) {
        if (signRes.success) {
          if (!settings.hasLinkedBiometrics) {
            settings.linkBiometricCredentials(email: email, password: pass);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác thực sinh trắc học hệ thống thành công!'),
              backgroundColor: AppDesignTokens.successEmerald,
            ),
          );
          widget.onLoginSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(signRes.message),
              backgroundColor: AppDesignTokens.dangerRose,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppDesignTokens.warningAmber,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14151C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF252A3A)),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.lock_reset_rounded,
              color: AppDesignTokens.brandPrimaryLight,
            ),
            SizedBox(width: 10),
            Text(
              'Quên Mật Khẩu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập email của bạn để nhận liên kết đặt lại mật khẩu:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailResetCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppDesignTokens.brandPrimaryLight,
                ),
                hintText: 'name@company.com',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0E1017),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF252A3A)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppDesignTokens.brandPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final auth = AuthService.instance;
              final res = await auth.sendPasswordResetEmail(
                emailResetCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success
                        ? AppDesignTokens.successEmerald
                        : AppDesignTokens.dangerRose,
                  ),
                );
              }
            },
            child: const Text('Gửi Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppDesignTokens.bgDark : AppDesignTokens.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppDesignTokens.cardSurface(isDark),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppDesignTokens.border(isDark)),
                          boxShadow: AppDesignTokens.softShadow(isDark),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.fingerprint_rounded,
                            color: AppDesignTokens.brandPrimaryLight,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Hệ Thống Chấm Công',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppDesignTokens.textPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Xác thực Khuôn mặt AI & Sinh trắc học',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppDesignTokens.textSecondary(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.cardSurface(isDark),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppDesignTokens.border(isDark)),
                        boxShadow: AppDesignTokens.softShadow(isDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _handleSystemBiometricLogin,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.subtleSurface(isDark),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppDesignTokens.border(isDark)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppDesignTokens.brandPrimary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.fingerprint_rounded,
                                      size: 20,
                                      color: AppDesignTokens.brandPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Sinh Trắc Học Hệ Thống',
                                          style: TextStyle(
                                            color: AppDesignTokens.textPrimary(isDark),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Dùng Vân tay hoặc Khuôn mặt thiết bị',
                                          style: TextStyle(
                                            color: AppDesignTokens.textSecondary(isDark),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppDesignTokens.textSecondary(isDark),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(child: Divider(color: AppDesignTokens.border(isDark))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'Hoặc dùng tài khoản',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppDesignTokens.textMuted(isDark),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: AppDesignTokens.border(isDark))),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Email nhân viên',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.textSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: AppDesignTokens.textPrimary(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'name@company.com',
                              hintStyle: TextStyle(color: AppDesignTokens.textMuted(isDark)),
                              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19),
                              filled: true,
                              fillColor: AppDesignTokens.subtleSurface(isDark),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppDesignTokens.border(isDark)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppDesignTokens.brandPrimary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                              if (!v.contains('@')) return 'Email không hợp lệ';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mật khẩu',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.textSecondary(isDark),
                                ),
                              ),
                              InkWell(
                                onTap: _showForgotPasswordDialog,
                                child: const Text(
                                  'Quên mật khẩu?',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignTokens.brandPrimaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: AppDesignTokens.textPrimary(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Nhập ít nhất 6 ký tự',
                              hintStyle: TextStyle(color: AppDesignTokens.textMuted(isDark)),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 19,
                                  color: AppDesignTokens.textSecondary(isDark),
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: AppDesignTokens.subtleSurface(isDark),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppDesignTokens.border(isDark)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppDesignTokens.brandPrimary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                              if (v.length < 6) return 'Mật khẩu phải từ 6 ký tự trở lên';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          ListenableBuilder(
                            listenable: AuthService.instance,
                            builder: (context, _) {
                              final isLoading = AuthService.instance.isLoading;
                              return SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: isLoading ? null : _handleLogin,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppDesignTokens.brandPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Đăng Nhập Hệ Thống',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chưa có tài khoản nhân viên?',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppDesignTokens.textSecondary(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  onRegisterSuccess: widget.onLoginSuccess,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.brandPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.key_rounded,
                          size: 15,
                          color: AppDesignTokens.textSecondary(isDark),
                        ),
                        label: Text(
                          'Đổi mật khẩu tài khoản',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
