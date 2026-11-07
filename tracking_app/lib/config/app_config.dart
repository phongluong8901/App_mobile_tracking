import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AppConfig {
  static String? _customServerUrl;
  static String? _customUserId;
  static String? _customUserName;

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      print('[AppConfig] Không thể tải .env, dùng fallback mặc định: $e');
    }
  }

  // Server URL (ưu tiên cấu hình tùy chỉnh khi đổi trong app)
  static String get serverUrl =>
      _customServerUrl ?? dotenv.env['SERVER_URL'] ?? 'http://10.0.2.2:3000';

  static set serverUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _customServerUrl = cleanUrl;
  }

  static String get socketUrl =>
      _customServerUrl ?? dotenv.env['SOCKET_URL'] ?? serverUrl;

  // Thông tin nhân viên
  static String get currentUserId =>
      _customUserId ?? dotenv.env['CURRENT_USER_ID'] ?? 'NV_001';

  static set currentUserId(String id) {
    _customUserId = id.trim();
  }

  static String get userName =>
      _customUserName ?? dotenv.env['USER_NAME'] ?? 'Phong Luong';

  static set userName(String name) {
    _customUserName = name.trim();
  }

  static String get deviceId =>
      dotenv.env['DEVICE_ID'] ?? 'FLUTTER_DEVICE_01';

  // Cấu hình vị trí và bán kính chấm công của công ty (Geofence)
  static double officeLat = 21.028511;
  static double officeLng = 105.854444;
  static double officeRadius = 200.0; // mét
  static String officeName = 'Trụ sở công ty';

  /// Lấy cấu hình công ty từ Backend về
  static Future<void> fetchOfficeConfig() async {
    try {
      final uri = Uri.parse('$serverUrl/api/office-config');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          officeLat = (data['data']['lat'] as num).toDouble();
          officeLng = (data['data']['lng'] as num).toDouble();
          officeRadius = (data['data']['maxRadiusMeters'] as num).toDouble();
          final n = data['data']['name'];
          if (n is String && n.trim().isNotEmpty) officeName = n;
        }
      }
    } catch (_) {}
  }

  /// Cập nhật vị trí và bán kính chấm công lên Backend
  static Future<bool> saveOfficeConfig({
    required double lat,
    required double lng,
    required double radius,
    String? name,
  }) async {
    officeLat = lat;
    officeLng = lng;
    officeRadius = radius;
    if (name != null) officeName = name;

    try {
      final uri = Uri.parse('$serverUrl/api/office-config');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'maxRadiusMeters': radius,
          'name': officeName,
        }),
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Kiểm tra kết nối tới Server Backend (Ping /health)
  static Future<({bool isOnline, int pingMs, String message})> checkServerHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$serverUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool mongoOk = data['mongoConnected'] == true;
        final String mongoStatus = mongoOk ? '✓ MongoDB Atlas: Đã kết nối' : '⚠️ MongoDB: Chưa kết nối (đang dùng in-memory)';
        return (
          isOnline: true,
          pingMs: stopwatch.elapsedMilliseconds,
          message: 'Kết nối Backend OK (${stopwatch.elapsedMilliseconds}ms)\n$mongoStatus'
        );
      } else {
        return (
          isOnline: false,
          pingMs: stopwatch.elapsedMilliseconds,
          message: 'Server phản hồi mã lỗi HTTP ${response.statusCode}'
        );
      }
    } catch (e) {
      stopwatch.stop();
      return (
        isOnline: false,
        pingMs: -1,
        message: 'Không thể kết nối tới $serverUrl ($e)'
      );
    }
  }
}
