import 'package:flutter/material.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../theme/app_design_tokens.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisterSuccess;

  const RegisterScreen({
    super.key,
    required this.onRegisterSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Khối Công Nghệ & AI');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = AuthService.instance;
    final res = await auth.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
      employeeCode: _codeController.text,
      department: _departmentController.text,
    );

    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // Quay lại trang chính
      widget.onRegisterSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    final pal = settings.palette;
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Đăng Ký Nhân Viên Mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: pal.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.person_add_rounded, color: pal.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tạo Tài Khoản Điểm Danh',
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const Text(
                                      'Đồng bộ tài khoản với Firebase Auth & MongoDB',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Họ tên
                          _label('Họ và tên nhân viên *', isDark),
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDeco('Nguyễn Văn A', Icons.badge_outlined, isDark),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                          ),
                          const SizedBox(height: 12),

                          // Mã nhân viên
                          _label('Mã nhân viên (User ID)', isDark),
                          TextFormField(
                            controller: _codeController,
                            decoration: _inputDeco('NV_002 (Bỏ trống sẽ tự sinh)', Icons.tag_rounded, isDark),
                          ),
                          const SizedBox(height: 12),

                          // Email
                          _label('Email công việc *', isDark),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDeco('name@company.com', Icons.email_outlined, isDark),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                              if (!v.contains('@')) return 'Email không hợp lệ';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Phòng ban
                          _label('Phòng ban / Bộ phận', isDark),
                          TextFormField(
                            controller: _departmentController,
                            decoration: _inputDeco('Khối Công Nghệ & AI', Icons.apartment_rounded, isDark),
                          ),
                          const SizedBox(height: 12),

                          // Mật khẩu
                          _label('Mật khẩu *', isDark),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDeco(
                              'Tối thiểu 6 ký tự',
                              Icons.lock_outline_rounded,
                              isDark,
                              suffix: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                              if (v.length < 6) return 'Mật khẩu phải từ 6 ký tự';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Xác nhận mật khẩu
                          _label('Xác nhận mật khẩu *', isDark),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: _inputDeco(
                              'Nhập lại mật khẩu',
                              Icons.lock_reset_rounded,
                              isDark,
                              suffix: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),

                          // Button Đăng Ký
                          ListenableBuilder(
                            listenable: AuthService.instance,
                            builder: (context, _) {
                              final isLoading = AuthService.instance.isLoading;
                              return Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: AppDesignTokens.auroraGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppDesignTokens.glowShadow(AppDesignTokens.brandPrimary),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: isLoading ? null : _handleRegister,
                                    child: Center(
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'HOÀN TẤT ĐĂNG KÝ',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13.5,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Đã có tài khoản nhân viên?', style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF64748B), fontSize: 12.5)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800, color: pal.primary, fontSize: 12.5)),
                        ),
                      ],
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

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : const Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon, bool isDark, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
    );
  }
}

