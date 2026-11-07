import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessBlinkState {
  waitingForFace,
  faceDetected,
  eyesClosed,
  blinkCompleted,
}

/// 5 bước quét khuôn mặt đa góc chuẩn eKYC Ngân hàng
enum EkycFaceStep {
  lookStraight, // Bước 1: Nhìn thẳng chính diện
  turnLeft,     // Bước 2: Quay mặt sang Trái
  turnRight,    // Bước 3: Quay mặt sang Phải
  tiltOrSmile,  // Bước 4: Ngẩng nhẹ đầu hoặc Mỉm cười
  blinkConfirm, // Bước 5: Nhìn thẳng & Chớp mắt hoàn tất
  completed,    // Đã hoàn thành 5/5 góc (100%)
}

class EkycFrameResult {
  final EkycFaceStep step;
  final int completedSteps;
  final double progress;
  final bool stepJustCaptured;
  final Face? face;
  final String instruction;
  final double yaw;
  final double pitch;

  const EkycFrameResult({
    required this.step,
    required this.completedSteps,
    required this.progress,
    required this.stepJustCaptured,
    required this.face,
    required this.instruction,
    this.yaw = 0.0,
    this.pitch = 0.0,
  });
}

class FaceDetectorService {
  late final FaceDetector _detector;
  bool _eyesWereClosed = false;

  // Biến trạng thái cho luồng eKYC đa góc
  EkycFaceStep _currentEkycStep = EkycFaceStep.lookStraight;
  int _holdFramesCount = 0;
  bool? _firstTurnWasPositiveYaw;
  bool _ekycEyesClosed = false;

  FaceDetectorService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  EkycFaceStep get currentEkycStep => _currentEkycStep;

  /// Xử lý khung hình cho Chấm công nhanh hàng ngày (Nhìn thẳng + Chớp mắt)
  Future<({LivenessBlinkState state, Face? face, String message})> processFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final inputImage = buildInputImage(image, camera);
    if (inputImage == null) {
      return (
        state: LivenessBlinkState.waitingForFace,
        face: null,
        message: 'Lỗi định dạng khung hình',
      );
    }

    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) {
      _eyesWereClosed = false;
      return (
        state: LivenessBlinkState.waitingForFace,
        face: null,
        message: 'Không tìm thấy khuôn mặt trong khung hình',
      );
    }

    if (faces.length > 1) {
      _eyesWereClosed = false;
      return (
        state: LivenessBlinkState.waitingForFace,
        face: null,
        message: 'Chỉ cho phép 1 khuôn mặt trong khung hình!',
      );
    }

    final face = faces.first;
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;

    // Chu trình chớp mắt: Mở -> Nhắm (< 0.25) -> Mở lại (> 0.75)
    if (leftEye < 0.25 && rightEye < 0.25) {
      _eyesWereClosed = true;
      return (
        state: LivenessBlinkState.eyesClosed,
        face: face,
        message: 'Đã nhắm mắt... Hãy mở mắt ra!',
      );
    } else if (_eyesWereClosed && leftEye > 0.75 && rightEye > 0.75) {
      _eyesWereClosed = false;
      return (
        state: LivenessBlinkState.blinkCompleted,
        face: face,
        message: 'Xác thực chớp mắt hoàn tất! Đang trích xuất vector khuôn mặt...',
      );
    }

    return (
      state: LivenessBlinkState.faceDetected,
      face: face,
      message: 'Hãy nhìn vào camera và CHỚP MẮT để chấm công',
    );
  }

  /// Xử lý khung hình cho chế độ Đăng ký khuôn mặt đa góc (eKYC Ngân hàng 5 bước)
  Future<EkycFrameResult> processEkycRegistrationFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_currentEkycStep == EkycFaceStep.completed) {
      return const EkycFrameResult(
        step: EkycFaceStep.completed,
        completedSteps: 5,
        progress: 1.0,
        stepJustCaptured: false,
        face: null,
        instruction: 'Đã quét đủ 5 góc mặt eKYC (100%)!',
      );
    }

    final inputImage = buildInputImage(image, camera);
    if (inputImage == null) {
      return EkycFrameResult(
        step: _currentEkycStep,
        completedSteps: _currentEkycStep.index,
        progress: _currentEkycStep.index / 5.0,
        stepJustCaptured: false,
        face: null,
        instruction: 'Đang đọc luồng camera...',
      );
    }

    final faces = await _detector.processImage(inputImage);

    if (faces.isEmpty) {
      _holdFramesCount = 0;
      return EkycFrameResult(
        step: _currentEkycStep,
        completedSteps: _currentEkycStep.index,
        progress: _currentEkycStep.index / 5.0,
        stepJustCaptured: false,
        face: null,
        instruction: 'Hãy đưa khuôn mặt vào chính giữa vòng tròn',
      );
    }

    if (faces.length > 1) {
      _holdFramesCount = 0;
      return EkycFrameResult(
        step: _currentEkycStep,
        completedSteps: _currentEkycStep.index,
        progress: _currentEkycStep.index / 5.0,
        stepJustCaptured: false,
        face: null,
        instruction: 'Phát hiện nhiều người! Chỉ để 1 khuôn mặt trong khung hình.',
      );
    }

    final face = faces.first;
    final yaw = face.headEulerAngleY ?? 0.0;   // Góc quay Trái / Phải
    final pitch = face.headEulerAngleX ?? 0.0; // Góc Ngẩng / Cúi
    final smile = face.smilingProbability ?? 0.0;
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;

    switch (_currentEkycStep) {
      // BƯỚC 1: NHÌN THẲNG CHÍNH DIỆN
      case EkycFaceStep.lookStraight:
        if (yaw.abs() < 12.0 && pitch.abs() < 14.0) {
          _holdFramesCount++;
          if (_holdFramesCount >= 2) {
            _holdFramesCount = 0;
            _currentEkycStep = EkycFaceStep.turnLeft;
            return EkycFrameResult(
              step: _currentEkycStep,
              completedSteps: 1,
              progress: 0.2,
              stepJustCaptured: true,
              face: face,
              instruction: 'Bước 2/5: Hãy từ từ QUAY MẶT SANG TRÁI ⬅️',
              yaw: yaw,
              pitch: pitch,
            );
          }
          return EkycFrameResult(
            step: _currentEkycStep,
            completedSteps: 0,
            progress: 0.1,
            stepJustCaptured: false,
            face: face,
            instruction: 'Bước 1/5: Giữ nguyên nhìn thẳng...',
            yaw: yaw,
            pitch: pitch,
          );
        }
        _holdFramesCount = 0;
        return EkycFrameResult(
          step: _currentEkycStep,
          completedSteps: 0,
          progress: 0.0,
          stepJustCaptured: false,
          face: face,
          instruction: 'Bước 1/5: Hãy NHÌN THẲNG vào camera 🙂',
          yaw: yaw,
          pitch: pitch,
        );

      // BƯỚC 2: QUAY MẶT SANG TRÁI
      case EkycFaceStep.turnLeft:
        if (yaw.abs() > 16.0) {
          _holdFramesCount++;
          if (_holdFramesCount >= 2) {
            _firstTurnWasPositiveYaw = yaw > 0;
            _holdFramesCount = 0;
            _currentEkycStep = EkycFaceStep.turnRight;
            return EkycFrameResult(
              step: _currentEkycStep,
              completedSteps: 2,
              progress: 0.4,
              stepJustCaptured: true,
              face: face,
              instruction: 'Bước 3/5: Tuyệt vời! Giờ hãy QUAY MẶT SANG PHẢI ➡️',
              yaw: yaw,
              pitch: pitch,
            );
          }
        } else {
          _holdFramesCount = 0;
        }
        return EkycFrameResult(
          step: _currentEkycStep,
          completedSteps: 1,
          progress: 0.2,
          stepJustCaptured: false,
          face: face,
          instruction: 'Bước 2/5: Hãy từ từ QUAY MẶT SANG TRÁI ⬅️',
          yaw: yaw,
          pitch: pitch,
        );

      // BƯỚC 3: QUAY MẶT SANG PHẢI (Hướng ngược lại với Bước 2)
      case EkycFaceStep.turnRight:
        final bool isOppositeSide = _firstTurnWasPositiveYaw == true
            ? (yaw < -16.0)
            : (yaw > 16.0);
        if (isOppositeSide) {
          _holdFramesCount++;
          if (_holdFramesCount >= 2) {
            _holdFramesCount = 0;
            _currentEkycStep = EkycFaceStep.tiltOrSmile;
            return EkycFrameResult(
              step: _currentEkycStep,
              completedSteps: 3,
              progress: 0.6,
              stepJustCaptured: true,
              face: face,
              instruction: 'Bước 4/5: Hãy NGẨNG NHẸ ĐẦU hoặc MỈM CƯỜI 😊',
              yaw: yaw,
              pitch: pitch,
            );
          }
        } else {
          _holdFramesCount = 0;
        }
        return EkycFrameResult(
          step: _currentEkycStep,
          completedSteps: 2,
          progress: 0.4,
          stepJustCaptured: false,
          face: face,
          instruction: 'Bước 3/5: Hãy từ từ QUAY MẶT SANG PHẢI ➡️',
          yaw: yaw,
          pitch: pitch,
        );

      // BƯỚC 4: NGẨNG/CÚI NHẸ ĐẦU HOẶC MỈM CƯỜI
      case EkycFaceStep.tiltOrSmile:
        if (pitch.abs() > 9.5 || smile > 0.5) {
          _holdFramesCount++;
          if (_holdFramesCount >= 2) {
            _holdFramesCount = 0;
            _ekycEyesClosed = false;
            _currentEkycStep = EkycFaceStep.blinkConfirm;
            return EkycFrameResult(
              step: _currentEkycStep,
              completedSteps: 4,
              progress: 0.8,
              stepJustCaptured: true,
              face: face,
              instruction: 'Bước 5/5: Nhìn thẳng & CHỚP MẮT để hoàn tất 😉',
              yaw: yaw,
              pitch: pitch,
            );
          }
        } else {
          _holdFramesCount = 0;
        }
        return EkycFrameResult(
          step: _currentEkycStep,
          completedSteps: 3,
          progress: 0.6,
          stepJustCaptured: false,
          face: face,
          instruction: 'Bước 4/5: Hãy NGẨNG NHẸ ĐẦU lên hoặc MỈM CƯỜI 😊',
          yaw: yaw,
          pitch: pitch,
        );

      // BƯỚC 5: NHÌN THẲNG & CHỚP MẮT XÁC NHẬN
      case EkycFaceStep.blinkConfirm:
        if (leftEye < 0.30 && rightEye < 0.30) {
          _ekycEyesClosed = true;
          return EkycFrameResult(
            step: _currentEkycStep,
            completedSteps: 4,
            progress: 0.9,
            stepJustCaptured: false,
            face: face,
            instruction: 'Đã nhắm mắt... Hãy mở mắt ra để hoàn tất!',
            yaw: yaw,
            pitch: pitch,
          );
        } else if (_ekycEyesClosed && leftEye > 0.65 && rightEye > 0.65) {
          _ekycEyesClosed = false;
          _currentEkycStep = EkycFaceStep.completed;
          return EkycFrameResult(
            step: EkycFaceStep.completed,
            completedSteps: 5,
            progress: 1.0,
            stepJustCaptured: true,
            face: face,
            instruction: '✅ Đã quét đủ 5 góc mặt eKYC (100%)! Đang lưu khuôn mặt...',
            yaw: yaw,
            pitch: pitch,
          );
        }
        return EkycFrameResult(
          step: _currentEkycStep,
          completedSteps: 4,
          progress: 0.8,
          stepJustCaptured: false,
          face: face,
          instruction: 'Bước 5/5: Nhìn thẳng & CHỚP MẮT để hoàn tất 😉',
          yaw: yaw,
          pitch: pitch,
        );

      case EkycFaceStep.completed:
        return EkycFrameResult(
          step: EkycFaceStep.completed,
          completedSteps: 5,
          progress: 1.0,
          stepJustCaptured: false,
          face: face,
          instruction: '✅ Đã hoàn thành quét eKYC 5 góc!',
          yaw: yaw,
          pitch: pitch,
        );
    }
  }

  /// Đóng gói CameraImage thành InputImage của ML Kit
  InputImage? buildInputImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void resetLiveness() {
    _eyesWereClosed = false;
    _currentEkycStep = EkycFaceStep.lookStraight;
    _holdFramesCount = 0;
    _firstTurnWasPositiveYaw = null;
    _ekycEyesClosed = false;
  }

  void dispose() {
    _detector.close();
  }
}
