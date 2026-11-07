import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../controllers/attendance_controller.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import '../auth/change_password_screen.dart';
import '../auth/login_screen.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/employee_avatar_widget.dart';
import '../widgets/office_settings_dialog.dart';
import '../widgets/server_settings_dialog.dart';

class SettingsTab extends StatefulWidget {
  final AttendanceController controller;
  final Function(String message, bool isSuccess) onShowMessage;

  const SettingsTab({
    super.key,
    required this.controller,
    required this.onShowMessage,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final AppSettingsService _settings = AppSettingsService.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final isDark = _settings.isDarkMode;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWideFold = constraints.maxWidth >= 580;

            if (isWideFold) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1060),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildProfileAndAvatarCard(context, isDark),
                              const SizedBox(height: 14),
                              _buildBiometricSecurityCard(context, isDark),
                              const SizedBox(height: 14),
                              _buildThemeCustomizationCard(isDark),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildNotificationSettingsCard(isDark),
                              const SizedBox(height: 14),
                              _buildSmartFeaturesAndSystemCard(context, isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileAndAvatarCard(context, isDark),
                  const SizedBox(height: 12),
                  _buildBiometricSecurityCard(context, isDark),
                  const SizedBox(height: 12),
                  _buildNotificationSettingsCard(isDark),
                  const SizedBox(height: 12),
                  _buildThemeCustomizationCard(isDark),
                  const SizedBox(height: 12),
                  _buildSmartFeaturesAndSystemCard(context, isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== 1. HỒ SƠ & AVATAR NHÂN VIÊN ====================
  Widget _buildProfileAndAvatarCard(BuildContext context, bool isDark) {
    final pal = _settings.palette;

    return _sectionContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.badge_outlined,
            title: 'Hồ Sơ Nhân Sự & Ảnh Đại Diện',
            subtitle: 'Quản lý thông tin cá nhân & cập nhật avatar',
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Row(
              children: [
                EmployeeAvatarWidget(
                  size: 54,
                  borderRadius: 15,
                  showEditBadge: true,
                  onTap: _captureSelfieAvatar,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.controller.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppDesignTokens.textPrimary(isDark),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: pal.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.controller.userId,
                              style: TextStyle(
                                color: pal.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_settings.roleTitle} • ${_settings.department}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppDesignTokens.textSecondary(isDark),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditProfileDialog(context),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: AppDesignTokens.textSecondary(isDark),
                    size: 20,
                  ),
                  tooltip: 'Sửa thông tin hồ sơ',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _neutralActionBtn(
                  icon: Icons.camera_front_rounded,
                  label: 'Chụp Selfie Avatar',
                  isDark: isDark,
                  onTap: _captureSelfieAvatar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neutralActionBtn(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Sửa Hồ Sơ',
                  isDark: isDark,
                  onTap: () => _showEditProfileDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _neutralActionBtn(
                  icon: Icons.lock_reset_rounded,
                  label: 'Đổi Mật Khẩu',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neutralActionBtn(
                  icon: Icons.switch_account_outlined,
                  label: 'Đổi Tài Khoản',
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(
                          onLoginSuccess: () {
                            Navigator.pop(context);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Biểu tượng đại diện nhanh:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppSettingsService.avatarPresets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, idx) {
              final preset = AppSettingsService.avatarPresets[idx];
              final selected =
                  _settings.customAvatarBytes == null && _settings.avatarPresetIndex == idx;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _settings.selectAvatarPreset(idx),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? pal.primary.withValues(alpha: isDark ? 0.16 : 0.08)
                        : AppDesignTokens.subtleSurface(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? pal.primary : AppDesignTokens.border(isDark),
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: preset.gradient),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(preset.icon, color: Colors.white, size: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? AppDesignTokens.textPrimary(isDark)
                              : AppDesignTokens.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _neutralActionBtn({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppDesignTokens.textSecondary(isDark)),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppDesignTokens.textPrimary(isDark),
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppDesignTokens.subtleSurface(isDark),
        side: BorderSide(color: AppDesignTokens.border(isDark)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      ),
    );
  }

  Future<void> _captureSelfieAvatar() async {
    final res = await widget.controller.captureAvatarFromCamera();
    widget.onShowMessage(res.message, res.success);
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: AppConfig.userName);
    final idCtrl = TextEditingController(text: AppConfig.currentUserId);
    final roleCtrl = TextEditingController(text: _settings.roleTitle);
    final deptCtrl = TextEditingController(text: _settings.department);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Chỉnh Sửa Hồ Sơ Nhân Viên',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên nhân viên',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã nhân viên (User ID)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chức vụ / Vị trí',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phòng ban / Bộ phận',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              _settings.updateProfile(
                userName: nameCtrl.text,
                userId: idCtrl.text,
                roleTitle: roleCtrl.text,
                department: deptCtrl.text,
              );
              Navigator.pop(ctx);
              widget.onShowMessage('Đã lưu thông tin hồ sơ nhân viên!', true);
            },
            child: const Text('Lưu Thay Đổi'),
          ),
        ],
      ),
    );
  }

  // ==================== 2. SINH TRẮC HỌC HỆ THỐNG ====================
  Widget _buildBiometricSecurityCard(BuildContext context, bool isDark) {
    final pal = _settings.palette;
    final isLinked = _settings.hasLinkedBiometrics;

    return _sectionContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.fingerprint_rounded,
            title: 'Sinh Trắc Học Hệ Thống',
            subtitle: 'Mở khóa bằng Vân tay & Khuôn mặt của máy Samsung',
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLinked ? AppDesignTokens.successEmerald : AppDesignTokens.warningAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLinked
                            ? 'Đã liên kết: ${_settings.linkedBiometricEmail ?? "Tài khoản nhân viên"}'
                            : 'Chưa liên kết tài khoản đăng nhập 1-chạm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.textPrimary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showLinkBiometricDialog(context),
                        icon: Icon(isLinked ? Icons.edit_outlined : Icons.add_link_rounded, size: 16),
                        label: Text(
                          isLinked ? 'Cập Nhật Liên Kết' : 'Liên Kết Tài Khoản Ngay',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: pal.primary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (isLinked) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          _settings.unlinkBiometrics();
                          widget.onShowMessage('Đã hủy liên kết sinh trắc học!', false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppDesignTokens.textSecondary(isDark),
                          side: BorderSide(color: AppDesignTokens.border(isDark)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Gỡ Bỏ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: pal.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng nhập bằng Sinh trắc học',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        'Dùng chung Vân tay & Khuôn mặt hệ thống',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignTokens.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final res = await BiometricAuthService.instance.testFingerprintHardware();
                    widget.onShowMessage(res.message, res.success);
                  },
                  child: const Text('Thử Quét', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _settings.biometricLoginEnabled,
                  activeColor: pal.primary,
                  onChanged: (v) {
                    _settings.setBiometricLoginEnabled(v);
                    _settings.setFaceLoginEnabled(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Tự động hiện quét khi mở ứng dụng',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.textPrimary(isDark),
              ),
            ),
            subtitle: Text(
              'Gọi hộp thoại sinh trắc học ngay tại màn hình đăng nhập',
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(isDark)),
            ),
            value: _settings.autoBiometricPrompt,
            activeColor: pal.primary,
            onChanged: (v) => _settings.setAutoBiometricPrompt(v),
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Xác thực sinh trắc học trước khi gửi chấm công',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.textPrimary(isDark),
              ),
            ),
            subtitle: Text(
              'Bảo mật 2 lớp khi xác nhận điểm danh',
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(isDark)),
            ),
            value: _settings.requireBiometricForClockIn,
            activeColor: pal.primary,
            onChanged: (v) => _settings.setRequireBiometricForClockIn(v),
          ),
        ],
      ),
    );
  }

  void _showLinkBiometricDialog(BuildContext context) {
    final currentEmail =
        AuthService.instance.currentUser?.email ??
        _settings.linkedBiometricEmail ??
        '${widget.controller.userId.toLowerCase()}@company.com';
    final emailCtrl = TextEditingController(text: currentEmail);
    final passCtrl = TextEditingController(text: _settings.linkedBiometricPassword ?? '');
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Liên Kết Sinh Trắc Học',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập thông tin tài khoản để mở khóa nhanh bằng Vân tay hoặc Khuôn mặt hệ thống:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email tài khoản',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                if (emailCtrl.text.trim().isEmpty || !emailCtrl.text.contains('@')) {
                  widget.onShowMessage('Vui lòng nhập email hợp lệ!', false);
                  return;
                }
                if (passCtrl.text.length < 6) {
                  widget.onShowMessage('Mật khẩu phải từ 6 ký tự trở lên!', false);
                  return;
                }
                _settings.linkBiometricCredentials(
                  email: emailCtrl.text,
                  password: passCtrl.text,
                );
                Navigator.pop(ctx);
                widget.onShowMessage('Đã kích hoạt sinh trắc học cho ${emailCtrl.text}!', true);
              },
              child: const Text('Lưu & Kích Hoạt'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. THÔNG BÁO NHẮC CHẤM CÔNG ====================
  Widget _buildNotificationSettingsCard(bool isDark) {
    final pal = _settings.palette;
    final enabled = _settings.notificationsEnabled;
    final mins = _settings.remindBeforeMinutes;
    final nextInfo = _settings.nextScheduledReminder;
    final minutePresets = [5, 10, 15, 20, 30];

    return _sectionContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  icon: Icons.notifications_none_rounded,
                  title: 'Thông Báo Nhắc Chấm Công',
                  subtitle: 'Nhắc nhở tự động trước giờ vào ca / tan ca',
                  isDark: isDark,
                ),
              ),
              Switch(
                value: enabled,
                activeColor: pal.primary,
                onChanged: (v) => _settings.setNotificationsEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Row(
              children: [
                Icon(
                  enabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                  color: enabled ? pal.primary : AppDesignTokens.textSecondary(isDark),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled
                            ? 'Lần nhắc kế tiếp: ${nextInfo.notifyTime} (Trước $mins phút)'
                            : 'Đang tắt thông báo nhắc chấm công',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppDesignTokens.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled
                            ? 'Ca áp dụng: ${nextInfo.label} (${nextInfo.shiftTime})'
                            : 'Bật công tắc phía trên để nhận nhắc nhở',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppDesignTokens.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thời gian báo trước:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppDesignTokens.textSecondary(isDark),
                ),
              ),
              Text(
                'Trước $mins phút',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: minutePresets.map((m) {
              final selected = mins == m;
              return ChoiceChip(
                label: Text('Trước $m phút'),
                selected: selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selectedColor: pal.primary,
                backgroundColor: AppDesignTokens.subtleSurface(isDark),
                side: BorderSide(color: selected ? pal.primary : AppDesignTokens.border(isDark)),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : AppDesignTokens.textSecondary(isDark),
                ),
                onSelected: enabled ? (_) => _settings.setRemindBeforeMinutes(m) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          _shiftNotifyTile('MORNING_IN', 'Vào Ca Sáng (08:00)', _fmtRemindTime(8, 0, mins), _settings.remindMorningIn, enabled, isDark),
          _shiftNotifyTile('MORNING_OUT', 'Ra Nghỉ Trưa (12:00)', _fmtRemindTime(12, 0, mins), _settings.remindMorningOut, enabled, isDark),
          _shiftNotifyTile('AFTERNOON_IN', 'Vào Ca Chiều (13:30)', _fmtRemindTime(13, 30, mins), _settings.remindAfternoonIn, enabled, isDark),
          _shiftNotifyTile('AFTERNOON_OUT', 'Ra Ca Chiều (17:00)', _fmtRemindTime(17, 0, mins), _settings.remindAfternoonOut, enabled, isDark),

          const Divider(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Âm báo & Rung phản hồi',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.textPrimary(isDark),
              ),
            ),
            subtitle: Text(
              'Phát âm thanh và rung nhẹ khi tới giờ nhắc',
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(isDark)),
            ),
            value: _settings.soundAndVibration,
            activeColor: pal.primary,
            onChanged: enabled ? (v) => _settings.setSoundAndVibration(v) : null,
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _settings.triggerTestNotification,
              icon: const Icon(Icons.notifications_active_outlined, size: 17),
              label: const Text(
                'Gửi Thử Thông Báo Ngay',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppDesignTokens.textPrimary(isDark),
                backgroundColor: AppDesignTokens.subtleSurface(isDark),
                side: BorderSide(color: AppDesignTokens.border(isDark)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtRemindTime(int hour, int minute, int beforeMins) {
    final total = (hour * 60 + minute - beforeMins).clamp(0, 23 * 60 + 59);
    final hh = (total ~/ 60).toString().padLeft(2, '0');
    final mm = (total % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _shiftNotifyTile(
    String slot,
    String title,
    String notifyAt,
    bool checked,
    bool enabled,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: checked,
            activeColor: _settings.palette.primary,
            onChanged: enabled ? (v) => _settings.setShiftReminder(slot, v ?? true) : null,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: enabled ? AppDesignTokens.textPrimary(isDark) : AppDesignTokens.textMuted(isDark),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Text(
              'Báo $notifyAt',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: checked && enabled
                    ? AppDesignTokens.textPrimary(isDark)
                    : AppDesignTokens.textMuted(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 4. CHỦ ĐỀ & GIAO DIỆN ====================
  Widget _buildThemeCustomizationCard(bool isDark) {
    return _sectionContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.palette_outlined,
            title: 'Giao Diện & Chủ Đề',
            subtitle: 'Chuyển đổi chế độ Sáng / Tối & màu điểm nhấn',
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _themeModeButton(
                    selected: !isDark,
                    icon: Icons.light_mode_outlined,
                    label: 'Chế Độ Sáng',
                    isDark: isDark,
                    onTap: () => _settings.setDarkMode(false),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _themeModeButton(
                    selected: isDark,
                    icon: Icons.dark_mode_outlined,
                    label: 'Chế Độ Tối',
                    isDark: isDark,
                    onTap: () => _settings.setDarkMode(true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Màu điểm nhấn:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppSettingsService.themePalettes.map((tp) {
              final selected = _settings.themePaletteIndex == tp.index;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _settings.setThemePalette(tp.index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? tp.primary.withValues(alpha: isDark ? 0.16 : 0.08)
                        : AppDesignTokens.subtleSurface(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? tp.primary : AppDesignTokens.border(isDark),
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: tp.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tp.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? AppDesignTokens.textPrimary(isDark)
                              : AppDesignTokens.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _themeModeButton({
    required bool selected,
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppDesignTokens.cardSurface(isDark) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppDesignTokens.textPrimary(isDark)
                    : AppDesignTokens.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppDesignTokens.textPrimary(isDark)
                        : AppDesignTokens.textSecondary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 5. TIỆN ÍCH THÔNG MINH & KẾT NỐI ====================
  Widget _buildSmartFeaturesAndSystemCard(BuildContext context, bool isDark) {
    final pal = _settings.palette;

    return _sectionContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.tune_rounded,
            title: 'Tiện Ích & Cấu Hình Hệ Thống',
            subtitle: 'Tự động hóa thao tác & kết nối máy chủ',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Tự động chuyển sang ca kế tiếp',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.textPrimary(isDark),
              ),
            ),
            subtitle: Text(
              'Sau khi chấm Vào Sáng (08:00), tự chuyển sang Ra Trưa (12:00)',
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(isDark)),
            ),
            value: _settings.autoAdvanceSlot,
            activeColor: pal.primary,
            onChanged: (v) => _settings.setAutoAdvanceSlot(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Chấm công tự động khi chớp mắt',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.textPrimary(isDark),
              ),
            ),
            subtitle: Text(
              'Gửi điểm danh ngay khi xác thực thực thể sống thành công',
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(isDark)),
            ),
            value: _settings.autoCheckInOnBlink,
            activeColor: pal.primary,
            onChanged: (v) => _settings.setAutoCheckInOnBlink(v),
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: _neutralActionBtn(
                  icon: Icons.edit_location_alt_outlined,
                  label: 'Vị Trí & Bán Kính',
                  isDark: isDark,
                  onTap: () {
                    OfficeSettingsDialog.show(context, widget.controller, () {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _neutralActionBtn(
                  icon: Icons.dns_outlined,
                  label: 'Cấu Hình Server',
                  isDark: isDark,
                  onTap: () {
                    ServerSettingsDialog.show(context, widget.controller, () {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final pal = _settings.palette;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: pal.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: pal.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
