import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AttendanceApiResponse {
  final bool success;
  final String message;
  final dynamic data;

  AttendanceApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory AttendanceApiResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceApiResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'],
    );
  }
}

class AttendanceApiService {
  String? _customBaseUrl;

  AttendanceApiService({String? baseUrl}) : _customBaseUrl = baseUrl;

  String get currentBaseUrl => _customBaseUrl ?? AppConfig.serverUrl;

  /// Lấy danh sách IP tiềm năng trên cùng mạng Wi-Fi (Subnet Scan)
  Future<List<String>> _getLocalSubnetCandidates() async {
    final candidates = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          final parts = ip.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
            // Quét các địa chỉ IP máy tính phổ biến trong mạng nội bộ gia đình / văn phòng
            final popularHosts = [
              1, 2, 3, 4, 5, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
              10, 11, 12, 13, 14, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90
            ];
            for (final host in popularHosts) {
              candidates.add('http://$prefix$host:3000');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AttendanceApiService] Không thể duyệt network interface: $e');
    }
    return candidates;
  }

  /// Tự động dò tìm địa chỉ Server đang mở cổng 3000 (cùng mạng Wi-Fi, Emulator, hoặc Localhost)
  Future<String?> discoverWorkingServer() async {
    final defaultCandidates = <String>[
      currentBaseUrl,
      'http://10.0.2.2:3000',
      'http://localhost:3000',
      'http://127.0.0.1:3000',
    ];

    // Thử các địa chỉ thông dụng trước
    for (final candidate in defaultCandidates) {
      if (candidate.isEmpty) continue;
      try {
        final uri = Uri.parse('$candidate/health');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 900));
        if (res.statusCode == 200) {
          debugPrint('[AttendanceApiService] ✅ Tự động kết nối thành công tới Server: $candidate');
          AppConfig.serverUrl = candidate;
          _customBaseUrl = candidate;
          return candidate;
        }
      } catch (_) {}
    }

    // Nếu điện thoại và máy tính dùng chung Wi-Fi, tự động quét dải mạng Wi-Fi nội bộ
    debugPrint('[AttendanceApiService] Đang tự động quét tìm máy tính trong mạng Wi-Fi...');
    final subnetCandidates = await _getLocalSubnetCandidates();

    // Quét song song theo nhóm 10 IP để tìm ra ngay trong < 1.5 giây
    const batchSize = 10;
    for (var i = 0; i < subnetCandidates.length; i += batchSize) {
      final end = (i + batchSize < subnetCandidates.length) ? i + batchSize : subnetCandidates.length;
      final batch = subnetCandidates.sublist(i, end);

      final results = await Future.wait(batch.map((url) async {
        try {
          final res = await http.get(Uri.parse('$url/health')).timeout(const Duration(milliseconds: 500));
          if (res.statusCode == 200) return url;
        } catch (_) {}
        return null;
      }));

      final found = results.firstWhere((u) => u != null, orElse: () => null);
      if (found != null) {
        debugPrint('[AttendanceApiService] ✅ Đã tìm thấy máy tính trong cùng Wi-Fi tại: $found');
        AppConfig.serverUrl = found;
        _customBaseUrl = found;
        return found;
      }
    }

    return null;
  }

  /// Đăng ký vector khuôn mặt 192 chiều lần đầu lên Server & lưu vào MongoDB Atlas
  Future<AttendanceApiResponse> registerFace({
    required String userId,
    required String name,
    required List<double> embedding,
  }) async {
    final payload = {
      'userId': userId,
      'name': name,
      'embedding': embedding,
    };

    // Lần gọi 1: Thử gửi tới URL hiện tại
    try {
      final res = await _postJson('$currentBaseUrl/api/register-face', payload);
      return res;
    } catch (firstError) {
      debugPrint('[AttendanceApiService] Thử lần 1 thất bại ($currentBaseUrl). Đang tự quét Wi-Fi tìm Server...');

      // Tự động tìm IP máy tính trong cùng mạng Wi-Fi
      final workingServer = await discoverWorkingServer();
      if (workingServer != null && workingServer != currentBaseUrl) {
        try {
          debugPrint('[AttendanceApiService] Tự động kết nối lại tới Server vừa tìm thấy: $workingServer');
          return await _postJson('$workingServer/api/register-face', payload);
        } catch (retryError) {
          debugPrint('[AttendanceApiService] Lỗi khi retry: $retryError');
        }
      }

      return AttendanceApiResponse(
        success: false,
        message: 'Không thể kết nối đến Backend ($currentBaseUrl):\n'
            '1. Đảm bảo bạn đã chạy "npm run dev" trong thư mục backend trên máy tính.\n'
            '2. Bấm vào icon Cài đặt (⚙️) góc trên để bấm "Tự quét tìm máy tính qua Wi-Fi".',
      );
    }
  }

  /// Điểm danh: Xác thực GPS, chống Fake GPS & đối chiếu khuôn mặt (Hỗ trợ CHECK_IN / CHECK_OUT)
  Future<AttendanceApiResponse> checkIn({
    required String userId,
    String type = 'CHECK_IN',
    required double lat,
    required double lng,
    required bool isMocked,
    required List<double> embedding,
    String? deviceId,
  }) async {
    final payload = {
      'userId': userId,
      'type': type,
      'lat': lat,
      'lng': lng,
      'isMocked': isMocked,
      'embedding': embedding,
      'deviceId': deviceId ?? AppConfig.deviceId,
    };

    try {
      return await _postJson('$currentBaseUrl/api/check-in', payload);
    } catch (firstError) {
      debugPrint('[AttendanceApiService] checkIn lỗi lần 1 ($currentBaseUrl). Đang tự quét Wi-Fi...');
      final workingServer = await discoverWorkingServer();
      if (workingServer != null && workingServer != currentBaseUrl) {
        try {
          return await _postJson('$workingServer/api/check-in', payload);
        } catch (_) {}
      }

      return AttendanceApiResponse(
        success: false,
        message: 'Không thể kết nối Server ($currentBaseUrl) để điểm danh.\n'
            'Hãy kiểm tra backend đã chạy "npm run dev" và bấm icon Cài đặt (⚙️) góc trên.',
      );
    }
  }

  /// Helper thực hiện POST JSON với timeout 8s
  Future<AttendanceApiResponse> _postJson(String url, Map<String, dynamic> body) async {
    final uri = Uri.parse(url);
    debugPrint('[AttendanceApiService] POST $uri...');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            throw TimeoutException('Quá thời gian chờ (Timeout sau 8s) khi kết nối tới $url');
          },
        );

    debugPrint('[AttendanceApiService] HTTP ${response.statusCode} <- $url');
    final Map<String, dynamic> json = jsonDecode(response.body);
    return AttendanceApiResponse.fromJson(json);
  }

  /// Lấy danh sách lịch sử chấm công từ MongoDB Atlas qua Backend
  Future<List<Map<String, dynamic>>> fetchAttendanceLogs({
    String? userId,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }

      final uri = Uri.parse('$currentBaseUrl/api/attendance-logs').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
    } catch (e) {
      debugPrint('[AttendanceApiService] Lỗi fetchAttendanceLogs: $e');
    }
    return [];
  }
}
