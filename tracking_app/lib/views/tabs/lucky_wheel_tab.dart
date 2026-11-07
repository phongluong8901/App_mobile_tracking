import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../theme/app_design_tokens.dart';

class RewardItem {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final int points;

  const RewardItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.points,
  });
}

class LuckyWheelTab extends StatefulWidget {
  final Function(String message, bool isSuccess) onShowMessage;

  const LuckyWheelTab({
    super.key,
    required this.onShowMessage,
  });

  @override
  State<LuckyWheelTab> createState() => _LuckyWheelTabState();
}

class _LuckyWheelTabState extends State<LuckyWheelTab> with SingleTickerProviderStateMixin {
  // Bảng màu vòng quay hiện đại, sang trọng, đồng bộ tông Indigo - Slate
  static const List<RewardItem> rewards = [
    RewardItem(
      label: '+50.000đ Thưởng',
      description: 'Cộng trực tiếp vào kỳ lương tháng',
      icon: Icons.monetization_on_rounded,
      color: Color(0xFF4F46E5),
      points: 50000,
    ),
    RewardItem(
      label: 'Vé Cà Phê Free',
      description: '1 Ly Highlands / The Coffee House',
      icon: Icons.coffee_rounded,
      color: Color(0xFF1E293B),
      points: 45000,
    ),
    RewardItem(
      label: '+100 Điểm Thưởng',
      description: 'Tích điểm đổi quà cuối năm',
      icon: Icons.stars_rounded,
      color: Color(0xFF6366F1),
      points: 100,
    ),
    RewardItem(
      label: 'Ân Hạn 15 Phút',
      description: 'Miễn trừ 1 lần đi muộn trong tháng',
      icon: Icons.alarm_on_rounded,
      color: Color(0xFF334155),
      points: 0,
    ),
    RewardItem(
      label: '+20.000đ Thưởng',
      description: 'Thưởng nóng chuyên cần',
      icon: Icons.savings_rounded,
      color: Color(0xFF0D9488),
      points: 20000,
    ),
    RewardItem(
      label: 'Trà Sữa Phúc Long',
      description: '1 Voucher đồ uống miễn phí',
      icon: Icons.local_drink_rounded,
      color: Color(0xFF1E293B),
      points: 55000,
    ),
    RewardItem(
      label: 'Vé Về Sớm 30p',
      description: 'Được phép về sớm 30p chiều thứ 6',
      icon: Icons.directions_run_rounded,
      color: Color(0xFF4338CA),
      points: 0,
    ),
    RewardItem(
      label: 'Chúc Bạn May Mắn',
      description: 'Tiếp tục check-in đúng giờ nhé!',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFF334155),
      points: 0,
    ),
  ];

  late AnimationController _wheelAnimCtrl;
  late Animation<double> _wheelAnimation;
  double _currentAngle = 0.0;
  bool _isSpinning = false;
  int _spinsLeftToday = 3;
  RewardItem? _lastReward;

  // LẮC ĐIỆN THOẠI BẰNG CẢM BIẾN GIA TỐC KẾ (ACCELEROMETER)
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  DateTime _lastShakeTime = DateTime.now();
  double _currentGForce = 1.0;
  double _shakeMeterProgress = 0.0;
  Timer? _decayTimer;

  @override
  void initState() {
    super.initState();
    _wheelAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _initAccelerometerShakeSensor();
  }

  void _initAccelerometerShakeSensor() {
    try {
      _sensorSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        if (!mounted || _isSpinning) return;

        final gX = event.x / 9.80665;
        final gY = event.y / 9.80665;
        final gZ = event.z / 9.80665;
        final gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

        _currentGForce = gForce;

        if (gForce > 1.35) {
          final boost = ((gForce - 1.2) * 0.4).clamp(0.05, 0.45);
          _shakeMeterProgress = (_shakeMeterProgress + boost).clamp(0.0, 1.0);
          HapticFeedback.lightImpact();
          if (mounted) setState(() {});
        }

        if ((gForce >= 2.15 || _shakeMeterProgress >= 0.95) && !_isSpinning) {
          final now = DateTime.now();
          if (now.difference(_lastShakeTime).inMilliseconds > 2000) {
            _lastShakeTime = now;
            _shakeMeterProgress = 1.0;
            _spinWheel();
          }
        }
      });

      _decayTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (!mounted || _isSpinning) return;
        if (_shakeMeterProgress > 0) {
          setState(() {
            _shakeMeterProgress = max(0.0, _shakeMeterProgress - 0.08);
          });
        }
      });
    } catch (e) {
      debugPrint('Sensor not supported on this device: $e');
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _decayTimer?.cancel();
    _wheelAnimCtrl.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;
    if (_spinsLeftToday <= 0) {
      widget.onShowMessage('Bạn đã dùng hết 3 lượt quay may mắn hôm nay!', false);
      return;
    }

    setState(() {
      _isSpinning = true;
      _spinsLeftToday--;
      _shakeMeterProgress = 0.0;
    });

    HapticFeedback.heavyImpact();

    final random = Random();
    final targetIndex = random.nextInt(rewards.length);
    final sliceAngle = (2 * pi) / rewards.length;
    final extraRounds = 5 + random.nextInt(4);
    final targetAngle = (extraRounds * 2 * pi) + (targetIndex * sliceAngle) + (sliceAngle / 2);

    final startAngle = _currentAngle % (2 * pi);
    final totalRotation = targetAngle + (2 * pi - startAngle);

    _wheelAnimation = Tween<double>(
      begin: _currentAngle,
      end: _currentAngle + totalRotation,
    ).animate(CurvedAnimation(
      parent: _wheelAnimCtrl,
      curve: Curves.easeOutCubic,
    ));

    _wheelAnimation.addListener(() {
      setState(() {
        _currentAngle = _wheelAnimation.value;
      });
    });

    _wheelAnimCtrl.forward(from: 0.0).then((_) {
      _isSpinning = false;
      _lastReward = rewards[targetIndex];
      HapticFeedback.vibrate();
      setState(() {});
      _showRewardDialog(_lastReward!);
    });
  }

  void _showRewardDialog(RewardItem reward) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.cardSurface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppDesignTokens.border(isDark)),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignTokens.brandPrimary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(reward.icon, color: AppDesignTokens.brandPrimaryLight, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              'Chúc Mừng Bạn!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppDesignTokens.textPrimary(isDark),
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reward.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppDesignTokens.brandPrimaryLight,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reward.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppDesignTokens.textSecondary(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.brandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Nhận Thưởng Ngay',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideFold = constraints.maxWidth >= 580;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  _buildHeaderBanner(isDark),
                  const SizedBox(height: 20),
                  _buildWheelContainer(isWideFold, isDark),
                  const SizedBox(height: 20),
                  _buildShakeSensorDashboard(isDark),
                  const SizedBox(height: 16),
                  if (_lastReward != null) _buildRecentRewardCard(isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppDesignTokens.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.vibration_rounded, color: AppDesignTokens.brandPrimaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lắc Điện Thoại Để Quay',
                  style: TextStyle(
                    color: AppDesignTokens.textPrimary(isDark),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cầm chắc máy và lắc dứt khoát để kích hoạt cảm biến',
                  style: TextStyle(
                    color: AppDesignTokens.textSecondary(isDark),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppDesignTokens.subtleSurface(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppDesignTokens.border(isDark)),
            ),
            child: Text(
              '$_spinsLeftToday/3 lượt',
              style: TextStyle(
                color: AppDesignTokens.textPrimary(isDark),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelContainer(bool isWideFold, bool isDark) {
    final wheelSize = isWideFold ? 310.0 : 265.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: wheelSize + 18,
          height: wheelSize + 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppDesignTokens.cardSurface(isDark),
            border: Border.all(color: AppDesignTokens.border(isDark), width: 2),
            boxShadow: AppDesignTokens.softShadow(isDark),
          ),
        ),
        Transform.rotate(
          angle: _currentAngle,
          child: SizedBox(
            width: wheelSize,
            height: wheelSize,
            child: CustomPaint(
              painter: _WheelPainter(rewards: rewards),
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: Container(
            width: 22,
            height: 26,
            decoration: BoxDecoration(
              color: AppDesignTokens.brandPrimary,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 22),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onShowMessage('Hãy cầm máy và lắc mạnh để kích hoạt vòng quay!', true);
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0E1017),
              border: Border.all(
                color: _isSpinning ? AppDesignTokens.brandPrimaryLight : const Color(0xFF334155),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: _isSpinning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vibration_rounded, color: Colors.white, size: 22),
                        SizedBox(height: 2),
                        Text(
                          'LẮC MÁY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShakeSensorDashboard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: AppDesignTokens.brandPrimaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cảm Biến Lắc Gia Tốc Kế',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppDesignTokens.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      _isSpinning
                          ? 'Đang quay thưởng...'
                          : 'Lắc điện thoại qua lại để nạp đầy thanh lực',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppDesignTokens.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(_shakeMeterProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _shakeMeterProgress,
              minHeight: 8,
              backgroundColor: AppDesignTokens.subtleSurface(isDark),
              valueColor: const AlwaysStoppedAnimation<Color>(AppDesignTokens.brandPrimary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gia tốc hiện tại: ${_currentGForce.toStringAsFixed(1)}G',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppDesignTokens.textSecondary(isDark),
                ),
              ),
              TextButton.icon(
                onPressed: _isSpinning
                    ? null
                    : () {
                        HapticFeedback.heavyImpact();
                        _shakeMeterProgress = 1.0;
                        _spinWheel();
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Quay thử (Test)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.textSecondary(isDark),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRewardCard(bool isDark) {
    final r = _lastReward!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppDesignTokens.cardSurface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignTokens.border(isDark)),
        boxShadow: AppDesignTokens.softShadow(isDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppDesignTokens.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(r.icon, color: AppDesignTokens.brandPrimaryLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phần thưởng vừa nhận: ${r.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppDesignTokens.textPrimary(isDark),
                  ),
                ),
                Text(
                  r.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppDesignTokens.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<RewardItem> rewards;

  _WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / rewards.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.5;

    for (int i = 0; i < rewards.length; i++) {
      final startAngle = i * sweepAngle;
      paint.color = rewards[i].color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sweepAngle / 2);

      final textSpan = TextSpan(
        text: rewards[i].label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(radius * 0.34, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
