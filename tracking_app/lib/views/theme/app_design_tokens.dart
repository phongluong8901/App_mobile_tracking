import 'package:flutter/material.dart';

/// Hệ thống Design Tokens chuẩn Executive Minimalist (Phong cách Linear / Stripe / iOS 18)
/// Tối ưu độ tương phản chữ, loại bỏ màu mè rối mắt, chuẩn tiếng Việt không lỗi font.
class AppDesignTokens {
  // Brand Primary (Executive Indigo)
  static const Color brandPrimary = Color(0xFF6366F1);
  static const Color brandPrimaryLight = Color(0xFF818CF8);
  static const Color brandPrimaryDark = Color(0xFF4F46E5);

  // Semantic Status Colors (Chỉ dùng cho chấm trạng thái nhỏ / badge, không lạm dụng tô chữ)
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color successEmerald = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRose = Color(0xFFF43F5E);
  static const Color purpleViolet = Color(0xFF8B5CF6);
  static const Color neoIndigo = Color(0xFF4F46E5);

  // Dark Mode Surfaces (Zinc-Obsidian chuẩn Flagship)
  static const Color bgDark = Color(0xFF090A0F);
  static const Color surfaceDark = Color(0xFF0E1017);
  static const Color cardDark = Color(0xFF131620);
  static const Color cardDarkElevated = Color(0xFF1B1F2C);
  static const Color borderDark = Color(0xFF252A3A);
  static const Color borderSubtleDark = Color(0x1AFFFFFF);

  // Light Mode Surfaces
  static const Color bgLight = Color(0xFFF4F6FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardLightElevated = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtleLight = Color(0x0F0F172A);

  // Dynamic Typography Colors (Đảm bảo chữ luôn sắc nét, trung tính, dễ đọc)
  static Color textPrimary(bool isDark) =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  static Color textSecondary(bool isDark) =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  static Color textMuted(bool isDark) =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color cardSurface(bool isDark) => isDark ? cardDark : cardLight;

  static Color subtleSurface(bool isDark) =>
      isDark ? cardDarkElevated : cardLightElevated;

  static Color border(bool isDark) => isDark ? borderDark : borderLight;

  // Text Colors constants
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // Clean Executive Gradients (Đơn sắc tinh tế, không lòe loẹt)
  static const LinearGradient executiveGradient = LinearGradient(
    colors: [Color(0xFF161926), Color(0xFF1E2235)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF161924), Color(0xFF12141D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Box Shadows
  static List<BoxShadow> softShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.45)
            : const Color(0xFF0F172A).withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> floatingDockShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.75)
            : const Color(0xFF0F172A).withValues(alpha: 0.10),
        blurRadius: 24,
        spreadRadius: 1,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> glowShadow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.22),
        blurRadius: 14,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
