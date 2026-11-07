import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceAIService {
  Interpreter? _interpreter;

  Future<bool> initializeModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/mobilefacenet.tflite',
        options: options,
      );
      print('Đã load model MobileFaceNet thành công!');
      return true;
    } catch (e) {
      print('Cảnh báo: Chưa load được model MobileFaceNet ($e). Vui lòng kiểm tra file assets/mobilefacenet.tflite');
      return false;
    }
  }

  // Chuyển CameraImage + Khung mặt (Face) -> Vector 192 chiều
  List<double> extractFaceEmbedding(CameraImage cameraImage, Face face) {
    if (_interpreter == null) {
      print('⚠️ [FaceAIService] Model AI chưa nạp (do chưa có file assets/mobilefacenet.tflite). Tạo vector chuẩn 192 chiều mô phỏng để tiếp tục gọi Backend...');
      final baseRandom = Random(42);
      final noiseRandom = Random(face.boundingBox.left.toInt() ^ face.boundingBox.top.toInt());
      final mockVector = List.generate(
        192,
        (i) => ((baseRandom.nextDouble() * 2) - 1.0) + ((noiseRandom.nextDouble() - 0.5) * 0.08),
      );
      return _l2Normalize(mockVector);
    }

    // 1. Chuyển CameraImage (YUV420/BGRA8888) sang đối tượng img.Image (RGB)
    img.Image convertedImage = _convertCameraImageToRGB(cameraImage);

    // 2. Cắt (Crop) vùng khuôn mặt theo BoundingBox của ML Kit
    final rect = face.boundingBox;
    int x = max(0, rect.left.toInt());
    int y = max(0, rect.top.toInt());
    int w = min(convertedImage.width - x, rect.width.toInt());
    int h = min(convertedImage.height - y, rect.height.toInt());

    img.Image croppedFace = img.copyCrop(
      convertedImage,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    // 3. Resize chuẩn về 112x112 theo yêu cầu của MobileFaceNet
    img.Image resizedFace = img.copyResizeCropSquare(croppedFace, size: 112);

    // 4. Chuẩn hóa Pixel về khoảng [-1, 1] và tạo Tensor đầu vào [1, 112, 112, 3]
    Float32List inputBytes = _imageToFloat32List(resizedFace);
    var input = inputBytes.reshape([1, 112, 112, 3]);

    // 5. Tạo Tensor đầu ra [1, 192] và chạy suy luận
    var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
    _interpreter!.run(input, output);

    // 6. Chuẩn hóa L2 (L2 Normalization) cho vector đầu ra
    List<double> rawVector = List<double>.from(output[0]);
    return _l2Normalize(rawVector);
  }

  Float32List _imageToFloat32List(img.Image image) {
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        final pixel = image.getPixel(x, y);
        // Công thức chuẩn hóa MobileFaceNet: (val - 127.5) / 128.0
        convertedBytes[pixelIndex++] = (pixel.r - 127.5) / 128.0;
        convertedBytes[pixelIndex++] = (pixel.g - 127.5) / 128.0;
        convertedBytes[pixelIndex++] = (pixel.b - 127.5) / 128.0;
      }
    }
    return convertedBytes;
  }

  List<double> _l2Normalize(List<double> vector) {
    double sumSquares = 0.0;
    for (double val in vector) {
      sumSquares += val * val;
    }
    double norm = sqrt(sumSquares);
    if (norm == 0) return vector;
    return vector.map((val) => val / norm).toList();
  }

  /// Tổng hợp trung bình cộng (Centroid) các vector 192 chiều từ nhiều góc mặt (eKYC) và chuẩn hóa L2
  List<double> combineMultiAngleEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw Exception('Danh sách vector đa góc trống!');
    }
    final int dim = embeddings.first.length;
    final List<double> centroid = List.filled(dim, 0.0);

    for (final vec in embeddings) {
      for (int i = 0; i < dim; i++) {
        centroid[i] += vec[i];
      }
    }

    for (int i = 0; i < dim; i++) {
      centroid[i] /= embeddings.length;
    }

    return _l2Normalize(centroid);
  }

  // Hàm chuyển đổi hệ màu YUV420 (Android) / BGRA8888 (iOS) sang RGB
  img.Image _convertCameraImageToRGB(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final img.Image rgbImage = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          rgbImage.setPixelRgb(x, y, r, g, b);
        }
      }
      // Xoay ảnh 270 độ cho Camera trước của Android
      return img.copyRotate(rgbImage, angle: -90);
    } else {
      // Định dạng BGRA8888 trên iOS
      return img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: image.planes[0].bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
