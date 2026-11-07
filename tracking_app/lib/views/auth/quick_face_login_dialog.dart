import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/camera_service.dart';
import '../../services/face_detector_service.dart';

class QuickFaceLoginDialog extends StatefulWidget {
  final Function(bool success, String message) onVerified;

  const QuickFaceLoginDialog({
    super.key,
    required this.onVerified,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(bool success, String message) onVerified,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuickFaceLoginDialog(onVerified: onVerified),
    );
  }

  @override
  State<QuickFaceLoginDialog> createState() => _QuickFaceLoginDialogState();
}

class _QuickFaceLoginDialogState extends State<QuickFaceLoginDialog> with SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final FaceDetectorService _detectorService = FaceDetectorService();

  bool _isInit = false;
  bool _isProcessing = false;
  String _status = 'Đang khởi động Camera FaceID...';
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.initialize();
      await _cameraService.startImageStream(_processFrame);
      if (mounted) {
        setState(() {
          _isInit = true;
          _status = 'Hãy nhìn vào camera và CHỚP MẮT để đăng nhập';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Không thể mở camera: $e';
        });
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || !_isInit) return;
    _isProcessing = true;

    try {
      final camera = _cameraService.controller?.description;
      if (camera == null) return;

      final result = await _detectorService.processFrame(image, camera);

      if (result.state == LivenessBlinkState.blinkCompleted && result.face != null) {
        await _cameraService.stopImageStream();
        if (mounted) {
          setState(() {
            _status = '✓ Xác thực FaceID thành công!';
          });
          await Future.delayed(const Duration(milliseconds: 400));
          Navigator.pop(context);
          widget.onVerified(true, 'Đăng nhập FaceID thành công!');
        }
      } else {
        if (mounted && _status != result.message) {
          setState(() {
            _status = result.message;
          });
        }
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cameraService.dispose();
    _detectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Xác Thực FaceID AI Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),

            // Camera Cutout Oval
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInit && _cameraService.controller != null)
                      CameraPreview(_cameraService.controller!)
                    else
                      const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),

                    // Biometric Scanning Animation Overlay
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, _) {
                        return Positioned(
                          top: 40 + (_animCtrl.value * 180),
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.transparent, Color(0xFF38BDF8), Color(0xFF10B981), Colors.transparent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Khung ngắm oval
                    Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Trạng thái hướng dẫn
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

