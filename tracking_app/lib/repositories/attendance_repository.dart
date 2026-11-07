import '../models/attendance_model.dart';
import '../models/location_data.dart';
import '../services/attendance_api_service.dart';

class AttendanceRepository {
  final AttendanceApiService _apiService;

  AttendanceRepository({AttendanceApiService? apiService})
      : _apiService = apiService ?? AttendanceApiService();

  /// Đăng ký vector khuôn mặt gốc của nhân viên
  Future<({bool success, String message, dynamic data})> registerFace({
    required String userId,
    required String name,
    required List<double> embedding,
  }) async {
    final response = await _apiService.registerFace(
      userId: userId,
      name: name,
      embedding: embedding,
    );

    return (
      success: response.success,
      message: response.message,
      data: response.data,
    );
  }

  /// Gửi yêu cầu điểm danh (khuôn mặt + GPS + Fake GPS detection + Ca làm việc)
  Future<({bool success, String message, AttendanceRecordModel? record})> checkIn({
    required String userId,
    String type = 'CHECK_IN',
    required PositionData position,
    required List<double> embedding,
    required String deviceId,
  }) async {
    final response = await _apiService.checkIn(
      userId: userId,
      type: type,
      lat: position.latitude,
      lng: position.longitude,
      isMocked: position.isMocked,
      embedding: embedding,
      deviceId: deviceId,
    );

    AttendanceRecordModel? record;
    if (response.data != null && response.data is Map<String, dynamic>) {
      record = AttendanceRecordModel.fromJson(response.data);
    }

    return (
      success: response.success,
      message: response.message,
      record: record,
    );
  }

  /// Tải lịch sử chấm công từ MongoDB Atlas
  Future<List<AttendanceRecordModel>> getAttendanceLogs({
    String? userId,
    int limit = 50,
  }) async {
    final rawList = await _apiService.fetchAttendanceLogs(userId: userId, limit: limit);
    return rawList.map((e) => AttendanceRecordModel.fromJson(e)).toList();
  }
}
