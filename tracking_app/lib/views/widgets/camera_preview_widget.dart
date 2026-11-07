import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../services/face_detector_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  final CameraController? controller;
  final bool isLivenessVerified;
  final bool isEkycMode;
  final double ekycProgress;
  final int ekycCompletedSteps;
  final EkycFaceStep ekycStep;
  final String statusMessage;
  final VoidCallback? onReset;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.isLivenessVerified,
    this.isEkycMode = false,
    this.ekycProgress = 0.0,
    this.ekycCompletedSteps = 0,
    this.ekycStep = EkycFaceStep.lookStraight,
    this.statusMessage = '',
    this.onReset,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = widget.controller;
    if (cam == null || !cam.value.isInitialized) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090D16), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Color(0xFF38BDF8),
                    strokeWidth: 2.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Đang khởi tạo AI Camera...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final shortest = math.min(maxW, maxH);

        // Kích thước vùng quét tự co giãn chuẩn xác trên cả màn gập & màn mở Fold 4
        final apertureSize = (shortest * 0.68).clamp(140.0, 240.0);
        final ovalW = (shortest * 0.62).clamp(135.0, 220.0);
        final ovalH = (ovalW * 1.24).clamp(165.0, maxH * 0.68);

        final previewW = cam.value.previewSize?.height ?? 1;
        final previewH = cam.value.previewSize?.width ?? 1;

        return Container(
          color: const Color(0xFF090D16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Luồng Camera sắc nét
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: previewW,
                    height: previewH,
                    child: CameraPreview(cam),
                  ),
                ),
              ),

              // 2. Lớp mặt nạ Cutout Biometric + Tia quét AI (Animated HUD)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _scanCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _BiometricHudPainter(
                          isEkycMode: widget.isEkycMode,
                          isVerified: widget.isLivenessVerified,
                          scanValue: _scanCtrl.value,
                          ekycProgress: widget.ekycProgress,
                          apertureWidth: widget.isEkycMode ? apertureSize : ovalW,
                          apertureHeight: widget.isEkycMode ? apertureSize : ovalH,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. Mũi tên hướng dẫn góc quay khi ở chế độ eKYC
              if (widget.isEkycMode)
                SizedBox(
                  width: apertureSize,
                  height: apertureSize,
                  child: _buildDirectionOverlayIcon(),
                ),

              // 4. Pill trạng thái AI ở góc trên
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge AI Mode
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16).withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: widget.isEkycMode
                                ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                                : (widget.isLivenessVerified
                                    ? const Color(0xFF34D399).withValues(alpha: 0.7)
                                    : Colors.white24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.isEkycMode
                                    ? const Color(0xFF38BDF8)
                                    : (widget.isLivenessVerified
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFFBBF24)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.isEkycMode
                                    ? 'eKYC 360° • ${(widget.ekycProgress * 100).toInt()}%'
                                    : (widget.isLivenessVerified
                                        ? 'FaceID Verified'
                                        : 'MobileFaceNet AI'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Nút Quét lại nhanh ngay trên góc phải Camera
                    if (widget.isLivenessVerified && !widget.isEkycMode && widget.onReset != null)
                      Material(
                        color: const Color(0xFF090D16).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: widget.onReset,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Quét lại',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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

              // 5. Thanh hướng dẫn trực tiếp nổi ở đáy Camera (Floating Glass HUD)
              if (widget.statusMessage.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.isLivenessVerified
                            ? const Color(0xFF34D399).withValues(alpha: 0.65)
                            : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isEkycMode
                              ? Icons.face_retouching_natural_rounded
                              : (widget.isLivenessVerified
                                  ? Icons.verified_rounded
                                  : Icons.remove_red_eye_outlined),
                          color: widget.isLivenessVerified
                              ? const Color(0xFF34D399)
                              : const Color(0xFF38BDF8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.statusMessage,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectionOverlayIcon() {
    switch (widget.ekycStep) {
      case EkycFaceStep.turnLeft:
        return Align(
          alignment: Alignment.centerLeft,
          child: _directionBadge(Icons.arrow_back_rounded, const Color(0xFF38BDF8)),
        );
      case EkycFaceStep.turnRight:
        return Align(
          alignment: Alignment.centerRight,
          child: _directionBadge(Icons.arrow_forward_rounded, const Color(0xFF38BDF8)),
        );
      case EkycFaceStep.tiltOrSmile:
        return Align(
          alignment: Alignment.topCenter,
          child: _directionBadge(Icons.sentiment_satisfied_alt_rounded, const Color(0xFFFBBF24)),
        );
      case EkycFaceStep.blinkConfirm:
        return Align(
          alignment: Alignment.bottomCenter,
          child: _directionBadge(Icons.visibility_rounded, const Color(0xFF34D399)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _directionBadge(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16).withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/// CustomPainter vẽ mặt nạ tối xung quanh vùng nhận diện + tia laser quét + khung HUD góc
class _BiometricHudPainter extends CustomPainter {
  final bool isEkycMode;
  final bool isVerified;
  final double scanValue;
  final double ekycProgress;
  final double apertureWidth;
  final double apertureHeight;

  _BiometricHudPainter({
    required this.isEkycMode,
    required this.isVerified,
    required this.scanValue,
    required this.ekycProgress,
    required this.apertureWidth,
    required this.apertureHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 8);
    final rect = Rect.fromCenter(
      center: center,
      width: apertureWidth,
      height: apertureHeight,
    );

    // 1. Mặt nạ tối mờ bên ngoài vùng khuôn mặt (Cutout Mask)
    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()..addOval(rect);
    final maskPath = Path.combine(PathOperation.difference, fullPath, holePath);

    canvas.drawPath(
      maskPath,
      Paint()..color = const Color(0xFF090D16).withValues(alpha: 0.52),
    );

    final Color primaryColor = isVerified
        ? const Color(0xFF10B981)
        : (isEkycMode ? const Color(0xFF38BDF8) : const Color(0xFF60A5FA));

    // 2. Nếu là chế độ eKYC: Vẽ 60 vạch chia độ chuẩn ngân hàng
    if (isEkycMode) {
      final radius = apertureWidth / 2;
      const int totalTicks = 60;
      final int activeTicks = (ekycProgress * totalTicks).round();

      for (int i = 0; i < totalTicks; i++) {
        final double angle = -math.pi / 2 + (i * 2 * math.pi / totalTicks);
        final bool isActive = i < activeTicks;

        final tickPaint = Paint()
          ..color = isActive
              ? const Color(0xFF34D399)
              : Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = isActive ? 3.2 : 2.0
          ..strokeCap = StrokeCap.round;

        final double startR = radius + 4;
        final double endR = isActive ? radius + 13 : radius + 9;

        final p1 = Offset(
          center.dx + startR * math.cos(angle),
          center.dy + startR * math.sin(angle),
        );
        final p2 = Offset(
          center.dx + endR * math.cos(angle),
          center.dy + endR * math.sin(angle),
        );
        canvas.drawLine(p1, p2, tickPaint);
      }
    }

    // 3. Viền phát sáng quanh vùng nhận diện
    if (isVerified) {
      canvas.drawOval(
        rect.inflate(3),
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawOval(
      rect,
      Paint()
        ..color = isVerified
            ? const Color(0xFF34D399)
            : Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isVerified ? 3.0 : 1.8,
    );

    // 4. Vẽ 4 góc HUD công nghệ cao xung quanh khung
    final cornerRect = rect.inflate(10);
    final cornerLen = math.min(apertureWidth, apertureHeight) * 0.14;
    final cornerRadius = 14.0;
    final hudPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(cornerRect.left, cornerRect.top + cornerLen)
        ..lineTo(cornerRect.left, cornerRect.top + cornerRadius)
        ..quadraticBezierTo(cornerRect.left, cornerRect.top, cornerRect.left + cornerRadius, cornerRect.top)
        ..lineTo(cornerRect.left + cornerLen, cornerRect.top),
      hudPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(cornerRect.right - cornerLen, cornerRect.top)
        ..lineTo(cornerRect.right - cornerRadius, cornerRect.top)
        ..quadraticBezierTo(cornerRect.right, cornerRect.top, cornerRect.right, cornerRect.top + cornerRadius)
        ..lineTo(cornerRect.right, cornerRect.top + cornerLen),
      hudPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(cornerRect.left, cornerRect.bottom - cornerLen)
        ..lineTo(cornerRect.left, cornerRect.bottom - cornerRadius)
        ..quadraticBezierTo(cornerRect.left, cornerRect.bottom, cornerRect.left + cornerRadius, cornerRect.bottom)
        ..lineTo(cornerRect.left + cornerLen, cornerRect.bottom),
      hudPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(cornerRect.right - cornerLen, cornerRect.bottom)
        ..lineTo(cornerRect.right - cornerRadius, cornerRect.bottom)
        ..quadraticBezierTo(cornerRect.right, cornerRect.bottom, cornerRect.right, cornerRect.bottom - cornerRadius)
        ..lineTo(cornerRect.right, cornerRect.bottom - cornerLen),
      hudPaint,
    );

    // 5. Tia quét Laser chuyển động mượt khi đang chờ nhận diện
    if (!isVerified) {
      canvas.save();
      canvas.clipPath(holePath);
      final scanY = rect.top + 16 + (rect.height - 32) * scanValue;
      final scanRect = Rect.fromLTWH(rect.left, scanY - 18, rect.width, 36);

      canvas.drawRect(
        scanRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withValues(alpha: 0.0),
              primaryColor.withValues(alpha: 0.28),
              primaryColor.withValues(alpha: 0.0),
            ],
          ).createShader(scanRect),
      );

      canvas.drawLine(
        Offset(rect.left + 12, scanY),
        Offset(rect.right - 12, scanY),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.85)
          ..strokeWidth = 1.8,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BiometricHudPainter oldDelegate) {
    return oldDelegate.scanValue != scanValue ||
        oldDelegate.isVerified != isVerified ||
        oldDelegate.isEkycMode != isEkycMode ||
        oldDelegate.ekycProgress != ekycProgress ||
        oldDelegate.apertureWidth != apertureWidth ||
        oldDelegate.apertureHeight != apertureHeight;
  }
}
