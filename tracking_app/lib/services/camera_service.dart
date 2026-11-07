import 'dart:io';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  bool _isStreaming = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller != null && _controller!.value.isInitialized;
  bool get isStreaming => _isStreaming;

  Future<void> initialize() async {
    _availableCameras = await availableCameras();

    final frontCamera = _availableCameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _availableCameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
  }

  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (!isInitialized || _isStreaming) return;
    _isStreaming = true;
    await _controller!.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    if (!isInitialized || !_isStreaming) return;
    _isStreaming = false;
    await _controller!.stopImageStream();
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isStreaming = false;
  }
}

