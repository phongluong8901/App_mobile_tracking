import 'package:flutter/material.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/attendance_model.dart';
import '../../services/app_settings_service.dart';
import '../../services/biometric_auth_service.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/employee_avatar_widget.dart';
import '../widgets/office_settings_dialog.dart';
import '../widgets/server_settings_dialog.dart';

class AttendanceTab extends StatelessWidget {
  final AttendanceController controller;
  final Function(String message, bool isSuccess) onShowMessage;

  const AttendanceTab({
    super.key,
    required this.controller,
    required this.onShowMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideFold = constraints.maxWidth >= 580;

        final cameraHeight = isWideFold
            ? (constraints.maxHeight - 48).clamp(340.0, 560.0)
            : (constraints.maxHeight * 0.48).clamp(250.0, 360.0);

        if (isWideFold) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 12,
                      child: Column(
                        children: [
                          _buildCameraHero(cameraHeight, isDark),
                          if (controller.isEkycMode) ...[
                            const SizedBox(height: 12),
                            _buildEkycStepper(isDark),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildExecutiveHeader(context, isDark),
                          const SizedBox(height: 14),
                          if (controller.lastAttendanceRecord != null && !controller.isEkycMode) ...[
                            _buildModernResultCard(controller.lastAttendanceRecord!, isDark),
                            const SizedBox(height: 14),
                          ],
                          _buildShiftSlotSelector(isDark),
                          const SizedBox(height: 14),
                          _buildPrimaryActionDock(context, isDark),
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
              _buildExecutiveHeader(context, isDark),
              const SizedBox(height: 12),
              _buildCameraHero(cameraHeight, isDark),
              if (controller.isEkycMode) ...[
                const SizedBox(height: 10),
                _buildEkycStepper(isDark),
              ],
              if (controller.lastAttendanceRecord != null && !controller.isEkycMode) ...[
                const SizedBox(height: 12),
                _buildModernResultCard(controller.lastAttendanceRecord!, isDark),
              ],
              const SizedBox(height: 12),
              _buildShiftSlotSelector(isDark),
              const SizedBox(height: 14),
              _buildPrimaryActionDock(context, isDark),
            ],
          ),
        );
      },
    );
  }

  /// 1. EXECUTIVE HEADER (Neutral Typography + Status Dot)
  Widget _buildExecutiveHeader(BuildContext context, bool isDark) {
    final isInside = controller.isInsideGeofence;
    final distance = controller.distanceToOffice;
    final hasGps = distance >= 0;

    final Color dotColor = !hasGps
        ? AppDesignTokens.brandPrimaryLight
        : (isInside ? AppDesignTokens.successEmerald : AppDesignTokens.warningAmber);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Row(
        children: [
          EmployeeAvatarWidget(
            size: 46,
            borderRadius: 14,
            onTap: () => ServerSettingsDialog.show(context, controller, () {}),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => OfficeSettingsDialog.show(context, controller, () {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          controller.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.textPrimary(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.subtleSurface(isDark),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppDesignTokens.border(isDark)),
                        ),
                        child: Text(
                          controller.userId,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppDesignTokens.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          !hasGps
                              ? 'Đang định vị tín hiệu GPS...'
                              : (isInside
                                  ? 'Trong vùng hợp lệ (${distance.toStringAsFixed(0)}m / ${controller.officeRadius.toInt()}m)'
                                  : 'Cách văn phòng ${distance.toStringAsFixed(0)}m (Bán kính ${controller.officeRadius.toInt()}m)'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppDesignTokens.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: AppDesignTokens.textSecondary(isDark),
            ),
            tooltip: 'Chỉnh bán kính văn phòng',
            onPressed: () => OfficeSettingsDialog.show(context, controller, () {}),
          ),
        ],
      ),
    );
  }

  /// 2. CAMERA HERO HUD BIO SCANNER
  Widget _buildCameraHero(double height, bool isDark) {
    final verified = controller.isLivenessVerified;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF090A0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: verified
              ? AppDesignTokens.successEmerald.withValues(alpha: 0.7)
              : AppDesignTokens.border(isDark),
          width: verified ? 2.0 : 1.2,
        ),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CameraPreviewWidget(
          controller: controller.cameraController,
          isLivenessVerified: controller.isLivenessVerified,
          isEkycMode: controller.isEkycMode,
          ekycProgress: controller.ekycProgress,
          ekycCompletedSteps: controller.ekycCompletedSteps,
          ekycStep: controller.ekycStep,
          statusMessage: controller.statusMessage,
          onReset: () => controller.resetLiveness(),
        ),
      ),
    );
  }

  /// 3. STEPPER ĐĂNG KÝ eKYC 5 GÓC
  Widget _buildEkycStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignTokens.border(isDark)),
      ),
      child: Row(
        children: [
          Expanded(child: _stepItem(1, 'Thẳng', controller.ekycCompletedSteps >= 1, isDark)),
          Expanded(child: _stepItem(2, 'Trái', controller.ekycCompletedSteps >= 2, isDark)),
          Expanded(child: _stepItem(3, 'Phải', controller.ekycCompletedSteps >= 3, isDark)),
          Expanded(child: _stepItem(4, 'Cười', controller.ekycCompletedSteps >= 4, isDark)),
          Expanded(child: _stepItem(5, 'Chớp mắt', controller.ekycCompletedSteps >= 5, isDark)),
        ],
      ),
    );
  }

  Widget _stepItem(int step, String label, bool done, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? AppDesignTokens.brandPrimary : AppDesignTokens.subtleSurface(isDark),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: AppDesignTokens.textSecondary(isDark),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: done ? AppDesignTokens.textPrimary(isDark) : AppDesignTokens.textSecondary(isDark),
            fontSize: 10,
            fontWeight: done ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 4. RESULT CARD (KẾT QUẢ QUÉT THỰC TẾ)
  Widget _buildModernResultCard(AttendanceRecordModel record, bool isDark) {
    final ok = record.isSuccess;
    final Color statusDot = ok ? AppDesignTokens.successEmerald : AppDesignTokens.dangerRose;
    final timeStr = record.timestamp.length >= 19 ? record.timestamp.substring(11, 19) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusDot.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: statusDot,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok ? '${record.typeLabel} • ${record.shiftLabel}' : 'Chấm công chưa hợp lệ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppDesignTokens.textPrimary(isDark),
                  ),
                ),
              ),
              if (timeStr.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.subtleSurface(isDark),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppDesignTokens.textSecondary(isDark),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _metricBox('Khoảng cách GPS', '${record.distance}m', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _metricBox('Độ khớp FaceID', '${(record.similarity * 100).toStringAsFixed(1)}%', isDark)),
            ],
          ),
          if (record.rejectionReason != null && record.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.rejectionReason!,
              style: TextStyle(
                color: AppDesignTokens.textSecondary(isDark),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignTokens.subtleSurface(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: AppDesignTokens.textSecondary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.textPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. BỘ CHỌN 4 MỐC CA TRONG NGÀY (Thiết kế đồng nhất, không lòe loẹt)
  Widget _buildShiftSlotSelector(bool isDark) {
    final curSlot = controller.attendanceType;
    final today = controller.todayTimesheet;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 17,
                color: AppDesignTokens.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ca Làm Việc Hôm Nay',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppDesignTokens.textPrimary(isDark),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${today.workUnits.toStringAsFixed(1)} / 1.0 công',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.brandPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _slotCard('MORNING_IN', 'Vào Sáng', '08:00', today.morningIn, curSlot == 'MORNING_IN', isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _slotCard('MORNING_OUT', 'Ra Trưa', '12:00', today.morningOut, curSlot == 'MORNING_OUT', isDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _slotCard('AFTERNOON_IN', 'Vào Chiều', '13:30', today.afternoonIn, curSlot == 'AFTERNOON_IN', isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _slotCard('AFTERNOON_OUT', 'Ra Chiều', '17:00', today.afternoonOut, curSlot == 'AFTERNOON_OUT', isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotCard(
    String slot,
    String title,
    String stdTime,
    AttendanceRecordModel? rec,
    bool isSelected,
    bool isDark,
  ) {
    final bool done = rec != null;
    final Color primary = AppDesignTokens.brandPrimary;

    return Material(
      color: isSelected
          ? primary.withValues(alpha: isDark ? 0.14 : 0.08)
          : AppDesignTokens.subtleSurface(isDark),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.setAttendanceType(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? primary : AppDesignTokens.border(isDark),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.textPrimary(isDark),
                      ),
                    ),
                  ),
                  Text(
                    stdTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppDesignTokens.brandPrimaryLight : AppDesignTokens.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    done ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 13,
                    color: done ? AppDesignTokens.successEmerald : AppDesignTokens.textMuted(isDark),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      done ? '${rec.shortTime} • Đã chấm' : 'Chưa điểm danh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppDesignTokens.textSecondary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 6. PRIMARY HERO CHECK-IN BUTTON & ACTIONS
  Widget _buildPrimaryActionDock(BuildContext context, bool isDark) {
    final verified = controller.isLivenessVerified;
    final curSlot = controller.attendanceType;

    final String slotTitle = switch (curSlot) {
      'MORNING_IN' => 'Xác Nhận Vào Ca Sáng (08:00)',
      'MORNING_OUT' => 'Xác Nhận Ra Nghỉ Trưa (12:00)',
      'AFTERNOON_IN' => 'Xác Nhận Vào Ca Chiều (13:30)',
      _ => 'Xác Nhận Ra Ca Chiều (17:00)',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: verified ? AppDesignTokens.brandPrimary : AppDesignTokens.cardSurface(isDark),
            borderRadius: BorderRadius.circular(18),
            boxShadow: verified ? AppDesignTokens.glowShadow(AppDesignTokens.brandPrimary) : [],
            border: Border.all(
              color: verified ? AppDesignTokens.brandPrimaryLight : AppDesignTokens.border(isDark),
              width: 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: verified
                  ? () async {
                      final settings = AppSettingsService.instance;
                      if (settings.requireBiometricForClockIn) {
                        final bio = BiometricAuthService.instance;
                        final bioRes = await bio.authenticateFingerprint(
                          reason: 'Xác thực sinh trắc học để gửi điểm danh',
                        );
                        if (!bioRes.success) {
                          onShowMessage(bioRes.message, false);
                          return;
                        }
                      }
                      final result = await controller.submitCheckIn();
                      onShowMessage(result.message, result.success);
                    }
                  : () {
                      onShowMessage('Hãy nhìn vào camera và chớp mắt để mở khóa xác nhận!', false);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: verified
                            ? Colors.white.withValues(alpha: 0.18)
                            : AppDesignTokens.subtleSurface(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        verified ? Icons.fingerprint_rounded : Icons.lock_outline_rounded,
                        color: verified ? Colors.white : AppDesignTokens.textSecondary(isDark),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            verified ? slotTitle : 'Đang Chờ Xác Thực Thực Thể Sống',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: verified ? Colors.white : AppDesignTokens.textPrimary(isDark),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            verified
                                ? 'Sẵn sàng đối chiếu khuôn mặt & vị trí GPS'
                                : 'Nhìn thẳng vào camera và chớp mắt 1 lần',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: verified ? Colors.white.withValues(alpha: 0.8) : AppDesignTokens.textSecondary(isDark),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: verified ? Colors.white70 : AppDesignTokens.textMuted(isDark),
                      size: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionSubTile(
                icon: Icons.threesixty_rounded,
                title: 'Đăng Ký eKYC',
                sub: 'Quét 5 góc khuôn mặt',
                isDark: isDark,
                onTap: () => controller.startEkycMode(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionSubTile(
                icon: Icons.face_retouching_natural_rounded,
                title: 'Lưu Mặt Gốc',
                sub: verified ? 'Lưu dữ liệu khuôn mặt' : 'Chớp mắt để mở khóa',
                isDark: isDark,
                onTap: () async {
                  if (!verified) {
                    onShowMessage('Hãy nhìn camera và chớp mắt trước khi lưu mặt!', false);
                    return;
                  }
                  final res = await controller.registerFace();
                  onShowMessage(res.message, res.success);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionSubTile({
    required IconData icon,
    required String title,
    required String sub,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppDesignTokens.cardSurface(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignTokens.border(isDark)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.subtleSurface(isDark),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppDesignTokens.brandPrimaryLight, size: 18),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppDesignTokens.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppDesignTokens.textSecondary(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
