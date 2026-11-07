import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

class AvatarPreset {
  final int index;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const AvatarPreset({
    required this.index,
    required this.label,
    required this.icon,
    required this.gradient,
  });
}

class ThemePalette {
  final int index;
  final String name;
  final Color primary;
  final Color secondary;
  final List<Color> headerGradient;

  const ThemePalette({
    required this.index,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.headerGradient,
  });
}

class ShiftReminderAlert {
  final String slotType;
  final String title;
  final String body;
  final String shiftTime;
  final int minutesBefore;

  const ShiftReminderAlert({
    required this.slotType,
    required this.title,
    required this.body,
    required this.shiftTime,
    required this.minutesBefore,
  });
}

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();
  factory AppSettingsService() => instance;

  AppSettingsService._internal() {
    _startReminderScheduler();
  }

  // ================= 1. DANH SÁCH AVATAR & BẢNG MÀU =================
  static const List<AvatarPreset> avatarPresets = [
    AvatarPreset(
      index: 0,
      label: 'Developer',
      icon: Icons.terminal_rounded,
      gradient: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    ),
    AvatarPreset(
      index: 1,
      label: 'AI Engineer',
      icon: Icons.psychology_rounded,
      gradient: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    ),
    AvatarPreset(
      index: 2,
      label: 'Tech Lead',
      icon: Icons.rocket_launch_rounded,
      gradient: [Color(0xFF047857), Color(0xFF10B981)],
    ),
    AvatarPreset(
      index: 3,
      label: 'Product Mgr',
      icon: Icons.workspace_premium_rounded,
      gradient: [Color(0xFFB45309), Color(0xFFF59E0B)],
    ),
    AvatarPreset(
      index: 4,
      label: 'Security',
      icon: Icons.shield_rounded,
      gradient: [Color(0xFF0F172A), Color(0xFF334155)],
    ),
    AvatarPreset(
      index: 5,
      label: 'Designer',
      icon: Icons.palette_rounded,
      gradient: [Color(0xFFBE185D), Color(0xFFF43F5E)],
    ),
    AvatarPreset(
      index: 6,
      label: 'Cloud Ops',
      icon: Icons.cloud_done_rounded,
      gradient: [Color(0xFF0369A1), Color(0xFF0EA5E9)],
    ),
    AvatarPreset(
      index: 7,
      label: 'Director',
      icon: Icons.diamond_rounded,
      gradient: [Color(0xFF6D28D9), Color(0xFFEC4899)],
    ),
  ];

  static const List<ThemePalette> themePalettes = [
    ThemePalette(
      index: 0,
      name: 'Obsidian Indigo',
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF38BDF8),
      headerGradient: [Color(0xFF12131A), Color(0xFF1A1C26), Color(0xFF242738)],
    ),
    ThemePalette(
      index: 1,
      name: 'Cyber Cyan',
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF6366F1),
      headerGradient: [Color(0xFF0C1420), Color(0xFF112236), Color(0xFF18334E)],
    ),
    ThemePalette(
      index: 2,
      name: 'Mint Emerald',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF06B6D4),
      headerGradient: [Color(0xFF0A1C16), Color(0xFF0E2E23), Color(0xFF144233)],
    ),
    ThemePalette(
      index: 3,
      name: 'Deep Violet',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFEC4899),
      headerGradient: [Color(0xFF170E28), Color(0xFF24153F), Color(0xFF341E5C)],
    ),
    ThemePalette(
      index: 4,
      name: 'Monochrome OLED',
      primary: Color(0xFFE2E8F0),
      secondary: Color(0xFF94A3B8),
      headerGradient: [Color(0xFF111115), Color(0xFF1A1A20), Color(0xFF262630)],
    ),
  ];

  // ================= 2. STATE HỒ SƠ & AVATAR =================
  int _avatarPresetIndex = 0;
  Uint8List? _customAvatarBytes; // Ảnh selfie chụp trực tiếp từ camera làm Avatar
  String _department = 'Khối Công Nghệ & AI';
  String _roleTitle = 'Mobile & AI Engineer';

  int get avatarPresetIndex => _avatarPresetIndex;
  AvatarPreset get currentAvatarPreset =>
      avatarPresets[_avatarPresetIndex.clamp(0, avatarPresets.length - 1)];
  Uint8List? get customAvatarBytes => _customAvatarBytes;
  String get department => _department;
  String get roleTitle => _roleTitle;

  void selectAvatarPreset(int index) {
    _avatarPresetIndex = index.clamp(0, avatarPresets.length - 1);
    _customAvatarBytes = null;
    notifyListeners();
  }

  void setCustomAvatarBytes(Uint8List bytes) {
    _customAvatarBytes = bytes;
    notifyListeners();
  }

  void updateProfile({
    String? userName,
    String? userId,
    String? department,
    String? roleTitle,
  }) {
    if (userName != null && userName.trim().isNotEmpty) {
      AppConfig.userName = userName.trim();
    }
    if (userId != null && userId.trim().isNotEmpty) {
      AppConfig.currentUserId = userId.trim();
    }
    if (department != null && department.trim().isNotEmpty) {
      _department = department.trim();
    }
    if (roleTitle != null && roleTitle.trim().isNotEmpty) {
      _roleTitle = roleTitle.trim();
    }
    notifyListeners();
  }

  // ================= 3. STATE THEME & GIAO DIỆN =================
  bool _isDarkMode = false;
  int _themePaletteIndex = 0;

  bool get isDarkMode => _isDarkMode;
  int get themePaletteIndex => _themePaletteIndex;
  ThemePalette get palette =>
      themePalettes[_themePaletteIndex.clamp(0, themePalettes.length - 1)];

  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
  }

  void setThemePalette(int index) {
    _themePaletteIndex = index.clamp(0, themePalettes.length - 1);
    notifyListeners();
  }

  ThemeData get activeTheme {
    final pal = palette;
    if (_isDarkMode) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        cardColor: const Color(0xFF131620),
        dividerColor: const Color(0xFF252A3A),
        colorScheme: ColorScheme.dark(
          primary: pal.primary,
          secondary: pal.secondary,
          surface: const Color(0xFF131620),
          surfaceContainerHighest: const Color(0xFF1B1F2C),
          onSurface: const Color(0xFFF8FAFC),
          outline: const Color(0xFF252A3A),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B1F2C),
          contentTextStyle: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      colorScheme: ColorScheme.light(
        primary: pal.primary,
        secondary: pal.secondary,
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurface: const Color(0xFF0F172A),
        outline: const Color(0xFFE2E8F0),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ================= 4. STATE THÔNG BÁO NHẮC CHẤM CÔNG =================
  bool _notificationsEnabled = true;
  int _remindBeforeMinutes = 10; // Nhắc trước X phút (5, 10, 15, 30 phút)
  bool _remindMorningIn = true;     // 08:00
  bool _remindMorningOut = true;    // 12:00
  bool _remindAfternoonIn = true;   // 13:30
  bool _remindAfternoonOut = true;  // 17:00
  bool _soundAndVibration = true;

  // Tiện ích chấm công thông minh
  bool _autoAdvanceSlot = true;
  bool _autoCheckInOnBlink = false;

  bool get notificationsEnabled => _notificationsEnabled;
  int get remindBeforeMinutes => _remindBeforeMinutes;
  bool get remindMorningIn => _remindMorningIn;
  bool get remindMorningOut => _remindMorningOut;
  bool get remindAfternoonIn => _remindAfternoonIn;
  bool get remindAfternoonOut => _remindAfternoonOut;
  bool get soundAndVibration => _soundAndVibration;
  bool get autoAdvanceSlot => _autoAdvanceSlot;
  bool get autoCheckInOnBlink => _autoCheckInOnBlink;

  Timer? _reminderTimer;
  String? _lastTriggeredKey;
  ShiftReminderAlert? _activeBannerAlert;
  ShiftReminderAlert? get activeBannerAlert => _activeBannerAlert;

  void Function(ShiftReminderAlert alert)? onReminderAlert;

  void setNotificationsEnabled(bool val) {
    _notificationsEnabled = val;
    notifyListeners();
  }

  void setRemindBeforeMinutes(int mins) {
    _remindBeforeMinutes = mins.clamp(1, 60);
    notifyListeners();
  }

  void setShiftReminder(String slot, bool enabled) {
    switch (slot) {
      case 'MORNING_IN':
        _remindMorningIn = enabled;
        break;
      case 'MORNING_OUT':
        _remindMorningOut = enabled;
        break;
      case 'AFTERNOON_IN':
        _remindAfternoonIn = enabled;
        break;
      case 'AFTERNOON_OUT':
        _remindAfternoonOut = enabled;
        break;
    }
    notifyListeners();
  }

  void setSoundAndVibration(bool val) {
    _soundAndVibration = val;
    notifyListeners();
  }

  void setAutoAdvanceSlot(bool val) {
    _autoAdvanceSlot = val;
    notifyListeners();
  }

  void setAutoCheckInOnBlink(bool val) {
    _autoCheckInOnBlink = val;
    notifyListeners();
  }

  void dismissBannerAlert() {
    _activeBannerAlert = null;
    notifyListeners();
  }

  /// Tính toán mốc nhắc nhở tiếp theo trong ngày
  ({String label, String notifyTime, String shiftTime, String slotType}) get nextScheduledReminder {
    final now = DateTime.now();
    final curMins = now.hour * 60 + now.minute;

    final slots = <({String slot, String name, int shiftMins, bool enabled})>[
      (slot: 'MORNING_IN', name: 'Vào Ca Sáng', shiftMins: 8 * 60, enabled: _remindMorningIn),
      (slot: 'MORNING_OUT', name: 'Ra Nghỉ Trưa', shiftMins: 12 * 60, enabled: _remindMorningOut),
      (slot: 'AFTERNOON_IN', name: 'Vào Ca Chiều', shiftMins: 13 * 60 + 30, enabled: _remindAfternoonIn),
      (slot: 'AFTERNOON_OUT', name: 'Ra Ca Chiều', shiftMins: 17 * 60, enabled: _remindAfternoonOut),
    ];

    for (final s in slots) {
      if (!s.enabled) continue;
      final notifyMins = s.shiftMins - _remindBeforeMinutes;
      if (notifyMins >= curMins) {
        return (
          label: s.name,
          notifyTime: _fmtHm(notifyMins),
          shiftTime: _fmtHm(s.shiftMins),
          slotType: s.slot,
        );
      }
    }

    // Nếu đã qua hết các ca hôm nay -> Nhắc ca đầu tiên vào sáng mai
    final first = slots.firstWhere((e) => e.enabled, orElse: () => slots.first);
    final notifyMins = first.shiftMins - _remindBeforeMinutes;
    return (
      label: '${first.name} (Ngày mai)',
      notifyTime: _fmtHm(notifyMins),
      shiftTime: _fmtHm(first.shiftMins),
      slotType: first.slot,
    );
  }

  String _fmtHm(int totalMinutes) {
    final m = totalMinutes.clamp(0, 23 * 60 + 59);
    final hh = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _startReminderScheduler() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_notificationsEnabled) return;
      final now = DateTime.now();
      final curMins = now.hour * 60 + now.minute;

      final slots = <({String slot, String name, int shiftMins, bool enabled})>[
        (slot: 'MORNING_IN', name: 'Vào Ca Sáng', shiftMins: 8 * 60, enabled: _remindMorningIn),
        (slot: 'MORNING_OUT', name: 'Ra Nghỉ Trưa', shiftMins: 12 * 60, enabled: _remindMorningOut),
        (slot: 'AFTERNOON_IN', name: 'Vào Ca Chiều', shiftMins: 13 * 60 + 30, enabled: _remindAfternoonIn),
        (slot: 'AFTERNOON_OUT', name: 'Ra Ca Chiều', shiftMins: 17 * 60, enabled: _remindAfternoonOut),
      ];

      for (final s in slots) {
        if (!s.enabled) continue;
        final notifyMins = s.shiftMins - _remindBeforeMinutes;
        if (curMins == notifyMins) {
          final key = '${now.year}-${now.month}-${now.day}_${s.slot}_$notifyMins';
          if (_lastTriggeredKey != key) {
            _lastTriggeredKey = key;
            _fireAlert(
              ShiftReminderAlert(
                slotType: s.slot,
                title: '🔔 Sắp đến giờ ${s.name} (${_fmtHm(s.shiftMins)})',
                body: 'Còn $_remindBeforeMinutes phút nữa tới giờ ${s.name}. Hãy mở camera chấm công đúng giờ nhé!',
                shiftTime: _fmtHm(s.shiftMins),
                minutesBefore: _remindBeforeMinutes,
              ),
            );
          }
        }
      }
    });
  }

  /// Bắn thông báo nhắc chấm công ngay lập tức (dùng cho cả hẹn giờ thật & nút Test)
  void triggerTestNotification() {
    final next = nextScheduledReminder;
    _fireAlert(
      ShiftReminderAlert(
        slotType: next.slotType,
        title: '🔔 Nhắc Chấm Công: ${next.label} (${next.shiftTime})',
        body: 'Thông báo tự động trước $_remindBeforeMinutes phút (lúc ${next.notifyTime}). Bấm "Chấm Ngay" để mở Camera!',
        shiftTime: next.shiftTime,
        minutesBefore: _remindBeforeMinutes,
      ),
    );
  }

  void _fireAlert(ShiftReminderAlert alert) {
    _activeBannerAlert = alert;
    if (_soundAndVibration) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    onReminderAlert?.call(alert);
    notifyListeners();
  }

  // ================= 5. BẢO MẬT SINH TRẮC HỌC (VÂN TAY & FACE ID) =================
  bool _biometricLoginEnabled = true; // Cho phép đăng nhập bằng vân tay
  bool _faceLoginEnabled = true;      // Cho phép đăng nhập bằng Face ID AI
  bool _autoBiometricPrompt = false;  // Tự động mở quét vân tay/mặt khi mở app
  bool _requireBiometricForClockIn = false; // Yêu cầu xác thực sinh trắc học trước khi gửi chấm công
  String? _linkedBiometricEmail;     // Email tài khoản liên kết sinh trắc học
  String? _linkedBiometricPassword;  // Mật khẩu xác thực ủy quyền
  DateTime? _biometricLinkedAt;      // Thời điểm kích hoạt

  bool get biometricLoginEnabled => _biometricLoginEnabled;
  bool get faceLoginEnabled => _faceLoginEnabled;
  bool get autoBiometricPrompt => _autoBiometricPrompt;
  bool get requireBiometricForClockIn => _requireBiometricForClockIn;
  String? get linkedBiometricEmail => _linkedBiometricEmail;
  String? get linkedBiometricPassword => _linkedBiometricPassword;
  DateTime? get biometricLinkedAt => _biometricLinkedAt;
  bool get hasLinkedBiometrics =>
      _linkedBiometricEmail != null &&
      _linkedBiometricEmail!.isNotEmpty &&
      _linkedBiometricPassword != null &&
      _linkedBiometricPassword!.isNotEmpty;

  void setBiometricLoginEnabled(bool val) {
    _biometricLoginEnabled = val;
    notifyListeners();
  }

  void setFaceLoginEnabled(bool val) {
    _faceLoginEnabled = val;
    notifyListeners();
  }

  void setAutoBiometricPrompt(bool val) {
    _autoBiometricPrompt = val;
    notifyListeners();
  }

  void setRequireBiometricForClockIn(bool val) {
    _requireBiometricForClockIn = val;
    notifyListeners();
  }

  void linkBiometricCredentials({
    required String email,
    required String password,
  }) {
    _linkedBiometricEmail = email.trim();
    _linkedBiometricPassword = password;
    _biometricLinkedAt = DateTime.now();
    _biometricLoginEnabled = true;
    _faceLoginEnabled = true;
    notifyListeners();
  }

  void unlinkBiometrics() {
    _linkedBiometricEmail = null;
    _linkedBiometricPassword = null;
    _biometricLinkedAt = null;
    notifyListeners();
  }
}

