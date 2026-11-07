import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/attendance_controller.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/location_tab.dart';
import 'tabs/lucky_wheel_tab.dart';
import 'tabs/settings_tab.dart';
import 'theme/app_design_tokens.dart';
import 'widgets/employee_avatar_widget.dart';
import 'widgets/office_settings_dialog.dart';
import 'widgets/server_settings_dialog.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceController _controller;
  final AppSettingsService _settings = AppSettingsService.instance;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AttendanceController();
    _controller.initialize();
    _controller.addListener(_onControllerUpdate);
    _settings.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _showSnackBar(String message, bool isSuccess) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppDesignTokens.successEmerald : AppDesignTokens.dangerRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _settings.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isCompact = screenW < 360;
    final isDark = _settings.isDarkMode;
    final activeAlert = _settings.activeBannerAlert;

    final tabTitle = switch (_currentTabIndex) {
      0 => 'Chấm Công AI',
      1 => 'Bản Đồ Geofence',
      2 => 'Vòng Quay May Mắn',
      3 => 'Lịch & Bảng Công',
      _ => 'Cài Đặt Hệ Thống',
    };

    return Scaffold(
      backgroundColor: isDark ? AppDesignTokens.bgDark : AppDesignTokens.bgLight,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 62,
        titleSpacing: isCompact ? 10 : 16,
        backgroundColor: isDark ? AppDesignTokens.bgDark : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppDesignTokens.borderDark : const Color(0x140F172A),
            height: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppDesignTokens.auroraGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppDesignTokens.glowShadow(AppDesignTokens.brandPrimary),
              ),
              child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 22),
            ),
            SizedBox(width: isCompact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tabTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 14.5 : 16,
                            color: AppDesignTokens.textPrimary(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.successEmerald.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: AppDesignTokens.successEmerald, size: 6),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppDesignTokens.successEmerald,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _controller.officeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppDesignTokens.textSecondary(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Nút chỉnh bán kính cty
          _circleIconButton(
            icon: Icons.edit_location_alt_rounded,
            tooltip: 'Vị trí công ty & bán kính',
            color: AppDesignTokens.textSecondary(isDark),
            isDark: isDark,
            onPressed: () {
              OfficeSettingsDialog.show(context, _controller, () {
                if (mounted) setState(() {});
              });
            },
          ),
          const SizedBox(width: 6),

          // Nút Server Wi-Fi
          _circleIconButton(
            icon: Icons.dns_rounded,
            tooltip: 'Cài đặt Server Backend',
            color: AppDesignTokens.textSecondary(isDark),
            isDark: isDark,
            onPressed: () {
              ServerSettingsDialog.show(context, _controller, () {
                if (mounted) setState(() {});
              });
            },
          ),
          const SizedBox(width: 6),

          // Nút Đăng Xuất
          _circleIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Đăng xuất',
            color: AppDesignTokens.textSecondary(isDark),
            isDark: isDark,
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Xác Nhận Đăng Xuất', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản nhân viên này không?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppDesignTokens.dangerRose,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        AuthService.instance.signOut();
                      },
                      child: const Text('Đăng Xuất'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Avatar Employee Pill
          Padding(
            padding: EdgeInsets.only(right: isCompact ? 8 : 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _currentTabIndex = 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppDesignTokens.cardSurface(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppDesignTokens.border(isDark),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmployeeAvatarWidget(size: 24, borderRadius: 8),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isCompact ? 48 : 84),
                      child: Text(
                        _controller.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppDesignTokens.textPrimary(isDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (activeAlert != null) _buildReminderNotificationBanner(activeAlert),
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  AttendanceTab(controller: _controller, onShowMessage: _showSnackBar),
                  LocationTab(controller: _controller, onShowMessage: _showSnackBar),
                  LuckyWheelTab(onShowMessage: _showSnackBar),
                  HistoryTab(controller: _controller),
                  SettingsTab(controller: _controller, onShowMessage: _showSnackBar),
                ],
              ),
            ),
            // FLOATING DOCK NAVIGATION BAR (ISLAND STYLE)
            _buildFloatingIslandDock(context, isCompact, isDark),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppDesignTokens.border(isDark),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildReminderNotificationBanner(ShiftReminderAlert alert) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppDesignTokens.auroraGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppDesignTokens.glowShadow(AppDesignTokens.brandPrimary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  alert.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              _settings.dismissBannerAlert();
              _controller.setAttendanceType(alert.slotType);
              setState(() => _currentTabIndex = 0);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppDesignTokens.brandPrimaryDark,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Chấm Ngay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _settings.dismissBannerAlert,
            icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
          ),
        ],
      ),
    );
  }

  /// FLOATING ISLAND NAVIGATION DOCK (SIÊU HIỆN ĐẠI CHUẨN FLAGSHIP)
  Widget _buildFloatingIslandDock(BuildContext context, bool isCompact, bool isDark) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Nâng cao bottom bar lên phía trên thanh điều hướng hệ thống (gesture / 3-button bar)
    final liftBottom = (bottomInset > 0 ? bottomInset : 16.0) + 18.0;

    return Container(
      margin: EdgeInsets.fromLTRB(14, 4, 14, liftBottom),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF5131620) : const Color(0xF8FFFFFF),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppDesignTokens.border(isDark),
          width: 1.0,
        ),
        boxShadow: AppDesignTokens.floatingDockShadow(isDark),
      ),
      child: Row(
        children: [
          Expanded(child: _dockItem(0, Icons.face_retouching_natural_rounded, 'Chấm Công', isCompact, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _dockItem(1, Icons.radar_rounded, 'Bản Đồ', isCompact, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _dockItem(2, Icons.casino_rounded, 'Vòng Quay', isCompact, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _dockItem(3, Icons.calendar_month_rounded, 'Bảng Công', isCompact, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _dockItem(4, Icons.tune_rounded, 'Cài Đặt', isCompact, isDark)),
        ],
      ),
    );
  }

  Widget _dockItem(int idx, IconData icon, String label, bool isCompact, bool isDark) {
    final isSel = _currentTabIndex == idx;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentTabIndex = idx);
          if (idx == 1 && _controller.currentPosition == null) {
            _controller.fetchCurrentLocation();
          } else if (idx == 3) {
            _controller.fetchAttendanceLogs();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: isSel ? 9 : 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSel ? AppDesignTokens.brandPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 21,
                color: isSel ? Colors.white : AppDesignTokens.textSecondary(isDark),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCompact ? 10.0 : 11.0,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? Colors.white : AppDesignTokens.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
