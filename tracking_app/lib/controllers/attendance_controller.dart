import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/attendance_model.dart';
import '../models/location_data.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/user_repository.dart';
import '../services/app_settings_service.dart';
import '../services/camera_service.dart';
import '../services/face_ai_service.dart';
import '../services/face_detector_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';

class AttendanceController extends ChangeNotifier {
  // Services & Repositories
  final CameraService _cameraService = CameraService();
  final FaceDetectorService _faceDetectorService = FaceDetectorService();
  final FaceAIService _faceAIService = FaceAIService();
  final LocationService _locationService = LocationService();
  final SocketService _socketService = SocketService();
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  final UserRepository _userRepository = UserRepository();

  // State Variables
  bool _isInitialized = false;
  bool _isProcessingFrame = false;
  bool _isLivenessVerified = false;
  bool _isTrackingLocation = false;
  bool _isLoading = false;
  String _statusMessage = 'Đang khởi động hệ thống nhận diện...';
  List<double>? _latestFaceEmbedding;
  AttendanceRecordModel? _lastAttendanceRecord;
  PositionData? _currentPosition;
  final List<PositionData> _trackingHistory = [];
  String? _lastLocationError;
  LocationPermissionStatus _locationPermissionStatus = LocationPermissionStatus.denied;

  // State cho 4 mốc Ca làm việc chuẩn (08:00 - 12:00 | 13:30 - 17:00) & Lịch sử chấm công
  String _attendanceType = _detectShiftSlotByNow();
  final List<AttendanceRecordModel> _attendanceLogs = [];
  bool _isLoadingLogs = false;

  static String _detectShiftSlotByNow() {
    final now = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    if (mins < 10 * 60 + 30) return 'MORNING_IN';     // Trước 10:30 -> Vào Sáng (08:00)
    if (mins < 12 * 60 + 45) return 'MORNING_OUT';    // 10:30 - 12:45 -> Ra Trưa (12:00)
    if (mins < 15 * 60 + 15) return 'AFTERNOON_IN';   // 12:45 - 15:15 -> Vào Chiều (13:30)
    return 'AFTERNOON_OUT';                           // Sau 15:15 -> Ra Chiều (17:00)
  }

  // State cho chế độ Đăng ký khuôn mặt đa góc eKYC (như app ngân hàng)
  bool _isEkycMode = false;
  EkycFaceStep _ekycStep = EkycFaceStep.lookStraight;
  double _ekycProgress = 0.0;
  int _ekycCompletedSteps = 0;
  final List<List<double>> _ekycAngleEmbeddings = [];
  Function(String message, bool isSuccess)? onEkycCompletedCallback;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessingFrame => _isProcessingFrame;
  bool get isLivenessVerified => _isLivenessVerified;
  bool get isTrackingLocation => _isTrackingLocation;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  List<double>? get latestFaceEmbedding => _latestFaceEmbedding;
  AttendanceRecordModel? get lastAttendanceRecord => _lastAttendanceRecord;
  CameraController? get cameraController => _cameraService.controller;
  PositionData? get currentPosition => _currentPosition;
  List<PositionData> get trackingHistory => List.unmodifiable(_trackingHistory);
  bool get isSocketConnected => _socketService.isConnected;
  String? get lastLocationError => _lastLocationError;
  LocationPermissionStatus get locationPermissionStatus => _locationPermissionStatus;

  bool get isEkycMode => _isEkycMode;
  EkycFaceStep get ekycStep => _ekycStep;
  double get ekycProgress => _ekycProgress;
  int get ekycCompletedSteps => _ekycCompletedSteps;

  String get userId => _userRepository.getCurrentUser().userId;
  String get userName => _userRepository.getCurrentUser().name;

  String get attendanceType => _attendanceType;
  bool get isCheckOutMode =>
      _attendanceType == 'MORNING_OUT' ||
      _attendanceType == 'AFTERNOON_OUT' ||
      _attendanceType == 'CHECK_OUT';
  List<AttendanceRecordModel> get attendanceLogs => List.unmodifiable(_attendanceLogs);
  bool get isLoadingLogs => _isLoadingLogs;

  void setAttendanceType(String type) {
    if (_attendanceType == type) return;
    _attendanceType = type;
    notifyListeners();
  }

  /// Tải lịch sử chấm công từ MongoDB Atlas (tối đa 250 bản ghi cho bảng công cả tháng)
  Future<void> fetchAttendanceLogs() async {
    _isLoadingLogs = true;
    notifyListeners();
    try {
      final logs = await _attendanceRepository.getAttendanceLogs(userId: userId, limit: 250);
      _attendanceLogs
        ..clear()
        ..addAll(logs);
    } catch (_) {}
    _isLoadingLogs = false;
    notifyListeners();
  }

  /// Tổng hợp bảng chấm công 4 mốc (08:00 - 12:00 | 13:30 - 17:00) cho 1 ngày bất kỳ
  DailyTimesheetModel buildDailyTimesheet(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final dateKey = '$y-$m-$d';

    final dayRecords = _attendanceLogs.where((r) {
      final dt = r.localDateTime;
      if (dt == null) return false;
      return dt.year == date.year && dt.month == date.month && dt.day == date.day;
    }).toList();

    final validRecords = dayRecords.where((r) => r.isSuccess).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    AttendanceRecordModel? morningIn;
    AttendanceRecordModel? morningOut;
    AttendanceRecordModel? afternoonIn;
    AttendanceRecordModel? afternoonOut;

    for (final rec in validRecords) {
      final slot = rec.normalizedSlot;
      if (slot == 'MORNING_IN') {
        morningIn ??= rec; // Lấy lần vào sáng đầu tiên
      } else if (slot == 'MORNING_OUT') {
        morningOut = rec;  // Lấy lần ra trưa cuối cùng
      } else if (slot == 'AFTERNOON_IN') {
        afternoonIn ??= rec; // Lấy lần vào chiều đầu tiên
      } else if (slot == 'AFTERNOON_OUT') {
        afternoonOut = rec;  // Lấy lần ra chiều cuối cùng
      }
    }

    return DailyTimesheetModel(
      date: DateTime(date.year, date.month, date.day),
      dateKey: dateKey,
      morningIn: morningIn,
      morningOut: morningOut,
      afternoonIn: afternoonIn,
      afternoonOut: afternoonOut,
      allRecords: dayRecords,
    );
  }

  /// Bảng chấm công của ngày hôm nay
  DailyTimesheetModel get todayTimesheet => buildDailyTimesheet(DateTime.now());

  // Cấu hình Vị trí Công ty & Bán kính Geofence
  double get officeLat => AppConfig.officeLat;
  double get officeLng => AppConfig.officeLng;
  double get officeRadius => AppConfig.officeRadius;
  String get officeName => AppConfig.officeName;

  /// Khoảng cách từ vị trí hiện tại đến công ty (mét)
  double get distanceToOffice {
    if (_currentPosition == null) return -1;
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      officeLat,
      officeLng,
    );
  }

  /// Tính khoảng cách từ vị trí hiện tại tới một tọa độ bất kỳ (dùng cho xem trước khi đổi vị trí công ty)
  double calculateDistanceToOffice(double lat, double lng) {
    if (_currentPosition == null) return -1;
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  /// Kiểm tra có đang nằm trong bán kính chấm công hay không
  bool get isInsideGeofence {
    final dist = distanceToOffice;
    if (dist < 0) return false;
    return dist <= officeRadius;
  }

  /// Cập nhật vị trí công ty & bán kính chấm công (đồng bộ cả Backend & App)
  Future<bool> updateOfficeLocation({
    required double lat,
    required double lng,
    required double radius,
    String? name,
  }) async {
    final success = await AppConfig.saveOfficeConfig(
      lat: lat,
      lng: lng,
      radius: radius,
      name: name,
    );
    notifyListeners();
    return success;
  }

  /// Khởi tạo camera, AI model và kết nối Socket.IO
  Future<void> initialize() async {
    try {
      _statusMessage = 'Đang tải model MobileFaceNet...';
      notifyListeners();

      await _faceAIService.initializeModel();

      _statusMessage = 'Đang khởi động Camera...';
      notifyListeners();

      await _cameraService.initialize();

      // Kết nối Socket.IO
      _socketService.connect(AppConfig.socketUrl, onUpdate: notifyListeners);

      // Bắt đầu luồng khung hình từ camera
      await _cameraService.startImageStream(_handleCameraFrame);

      _isInitialized = true;
      _statusMessage = 'Hãy nhìn vào camera và CHỚP MẮT để xác thực';
      notifyListeners();

      // Tự động hỏi quyền GPS ngay sau khi khởi tạo xong Camera
      await requestLocationPermission();

      // Tải vị trí và bán kính công ty từ Backend
      AppConfig.fetchOfficeConfig().then((_) => notifyListeners());
      fetchAttendanceLogs();
    } catch (e) {
      _statusMessage = 'Lỗi khởi động: $e';
      notifyListeners();
    }
  }

  /// Xin quyền GPS và trả về trạng thái chi tiết
  Future<LocationPermissionStatus> requestLocationPermission() async {
    _locationPermissionStatus = await _locationService.requestPermissionWithStatus();
    if (_locationPermissionStatus == LocationPermissionStatus.granted && _currentPosition == null) {
      try {
        _currentPosition = await _locationService.getCurrentPosition();
        _lastLocationError = null;
      } catch (_) {}
    }
    notifyListeners();
    return _locationPermissionStatus;
  }

  Future<bool> openLocationSettings() => _locationService.openLocationSettings();

  Future<bool> openAppSettings() => _locationService.openAppSettings();

  /// Bật chế độ Đăng ký khuôn mặt đa góc eKYC (Quay 5 góc như app ngân hàng)
  void startEkycMode() {
    _isEkycMode = true;
    _isLivenessVerified = false;
    _latestFaceEmbedding = null;
    _ekycAngleEmbeddings.clear();
    _ekycStep = EkycFaceStep.lookStraight;
    _ekycProgress = 0.0;
    _ekycCompletedSteps = 0;
    _faceDetectorService.resetLiveness();
    _statusMessage = 'Bước 1/5: Hãy NHÌN THẲNG vào camera 🙂';
    notifyListeners();
  }

  /// Thoát chế độ eKYC về chế độ Chấm công nhanh
  void cancelEkycMode() {
    _isEkycMode = false;
    _ekycAngleEmbeddings.clear();
    _ekycStep = EkycFaceStep.lookStraight;
    _ekycProgress = 0.0;
    _ekycCompletedSteps = 0;
    _faceDetectorService.resetLiveness();
    _statusMessage = 'Hãy nhìn vào camera và CHỚP MẮT để chấm công';
    notifyListeners();
  }

  /// Xử lý khung hình camera (Chấm công nhanh hoặc Quét 5 góc eKYC)
  Future<void> _handleCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || !_isInitialized || _isLoading) return;
    if (!_isEkycMode && _isLivenessVerified) return;
    if (_isEkycMode && _ekycStep == EkycFaceStep.completed) return;

    _isProcessingFrame = true;

    try {
      final camera = _cameraService.controller?.description;
      if (camera == null) return;

      // LUỒNG 1: ĐĂNG KÝ KHUÔN MẶT ĐA GÓC (eKYC NGÂN HÀNG 5 BƯỚC)
      if (_isEkycMode) {
        final ekycResult = await _faceDetectorService.processEkycRegistrationFrame(
          image,
          camera,
        );

        _ekycStep = ekycResult.step;
        _ekycProgress = ekycResult.progress;
        _ekycCompletedSteps = ekycResult.completedSteps;
        _statusMessage = ekycResult.instruction;

        if (ekycResult.stepJustCaptured && ekycResult.face != null) {
          final angleEmbedding = _faceAIService.extractFaceEmbedding(
            image,
            ekycResult.face!,
          );
          _ekycAngleEmbeddings.add(angleEmbedding);
        }

        notifyListeners();

        // Khi hoàn tất đủ 5/5 góc mặt -> Tổng hợp vector trung bình chuẩn hóa & Gửi lên Backend
        if (ekycResult.step == EkycFaceStep.completed && _ekycAngleEmbeddings.isNotEmpty) {
          final listEmbeddings = List<List<double>>.from(_ekycAngleEmbeddings);
          _ekycAngleEmbeddings.clear(); // Xóa ngay để tránh bị gọi lặp lại frame sau
          _isEkycMode = false;
          _latestFaceEmbedding = _faceAIService.combineMultiAngleEmbeddings(
            listEmbeddings,
          );
          _isLivenessVerified = true;
          notifyListeners();

          final regResult = await registerFace();
          onEkycCompletedCallback?.call(regResult.message, regResult.success);
        }
        return;
      }

      // LUỒNG 2: CHẤM CÔNG NHANH HÀNG NGÀY (NHÌN THẲNG + CHỚP MẮT)
      final result = await _faceDetectorService.processFrame(image, camera);

      if (result.state == LivenessBlinkState.blinkCompleted && result.face != null) {
        final embedding = _faceAIService.extractFaceEmbedding(image, result.face!);

        _latestFaceEmbedding = embedding;
        _isLivenessVerified = true;
        _statusMessage = 'Xác thực thực thể sống hoàn tất! Hãy bấm Điểm danh.';
        notifyListeners();

        // Nếu người dùng bật chế độ "Chấm công tự động khi chớp mắt" trong Cài đặt
        if (AppSettingsService.instance.autoCheckInOnBlink) {
          final autoRes = await submitCheckIn();
          onEkycCompletedCallback?.call(autoRes.message, autoRes.success);
        }
      } else {
        if (_statusMessage != result.message) {
          _statusMessage = result.message;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[AttendanceController] Lỗi xử lý frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Đăng ký khuôn mặt gốc lên Server
  Future<({bool success, String message})> registerFace() async {
    if (_latestFaceEmbedding == null) {
      return (success: false, message: 'Chưa có dữ liệu vector khuôn mặt!');
    }

    _isLoading = true;
    _statusMessage = 'Đang lưu vector khuôn mặt vào MongoDB Atlas...';
    notifyListeners();

    try {
      final result = await _attendanceRepository.registerFace(
        userId: userId,
        name: userName,
        embedding: _latestFaceEmbedding!,
      );

      _statusMessage = result.message;
      return (success: result.success, message: result.message);
    } catch (e) {
      return (success: false, message: 'Lỗi đăng ký khuôn mặt: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thực hiện điểm danh (GPS + Anti-Fake GPS + Khớp vector mặt)
  Future<({bool success, String message, AttendanceRecordModel? record})> submitCheckIn() async {
    if (_latestFaceEmbedding == null) {
      return (
        success: false,
        message: 'Vui lòng chớp mắt để quét khuôn mặt trước khi điểm danh!',
        record: null
      );
    }

    _isLoading = true;
    _statusMessage = 'Đang xác thực tọa độ GPS & đối chiếu khuôn mặt...';
    notifyListeners();

    try {
      final position = await _locationService.getCurrentPosition();
      _currentPosition = position;

      final result = await _attendanceRepository.checkIn(
        userId: userId,
        type: _attendanceType,
        position: position,
        embedding: _latestFaceEmbedding!,
        deviceId: _userRepository.getDeviceId(),
      );

      _lastAttendanceRecord = result.record;
      if (result.record != null) {
        _attendanceLogs.removeWhere((e) => e.id == result.record!.id);
        _attendanceLogs.insert(0, result.record!);

        // Tự động chuyển sang mốc ca tiếp theo nếu chấm thành công
        if (result.success && AppSettingsService.instance.autoAdvanceSlot) {
          _advanceToNextShiftSlot();
        }
      }
      _statusMessage = result.message;
      return result;
    } catch (e) {
      final errorMsg = 'Lỗi điểm danh: $e';
      _statusMessage = errorMsg;
      return (success: false, message: errorMsg, record: null);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _advanceToNextShiftSlot() {
    final sheet = todayTimesheet;
    if (sheet.morningIn == null) {
      _attendanceType = 'MORNING_IN';
    } else if (sheet.morningOut == null) {
      _attendanceType = 'MORNING_OUT';
    } else if (sheet.afternoonIn == null) {
      _attendanceType = 'AFTERNOON_IN';
    } else {
      _attendanceType = 'AFTERNOON_OUT';
    }
  }

  /// Chụp ảnh Selfie trực tiếp từ Camera trước để đặt làm Avatar nhân viên
  Future<({bool success, String message})> captureAvatarFromCamera() async {
    final cam = _cameraService.controller;
    if (cam == null || !cam.value.isInitialized) {
      return (success: false, message: 'Camera chưa sẵn sàng để chụp ảnh đại diện.');
    }

    try {
      await _cameraService.stopImageStream();
      final xfile = await cam.takePicture();
      final bytes = await xfile.readAsBytes();
      AppSettingsService.instance.setCustomAvatarBytes(bytes);
      await _cameraService.startImageStream(_handleCameraFrame);
      notifyListeners();
      return (success: true, message: 'Đã cập nhật ảnh đại diện từ Camera thành công!');
    } catch (e) {
      try {
        await _cameraService.startImageStream(_handleCameraFrame);
      } catch (_) {}
      return (success: false, message: 'Không thể chụp ảnh đại diện: $e');
    }
  }

  /// Lấy vị trí GPS hiện tại độc lập (kèm hỏi cấp quyền tự động)
  Future<PositionData?> fetchCurrentLocation() async {
    _isLoading = true;
    _lastLocationError = null;
    notifyListeners();
    try {
      _locationPermissionStatus = await _locationService.requestPermissionWithStatus();
      final pos = await _locationService.getCurrentPosition();
      _currentPosition = pos;
      _lastLocationError = null;
      return pos;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _lastLocationError = msg;
      _statusMessage = msg;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Bật / Tắt chế độ Live Tracking qua Socket.IO
  Future<bool> toggleLiveTracking() async {
    if (_isTrackingLocation) {
      _isTrackingLocation = false;
      _locationService.stopListening();
      _statusMessage = 'Đã dừng Live Tracking.';
      notifyListeners();
      return false;
    }

    final perm = await requestLocationPermission();
    if (perm != LocationPermissionStatus.granted) {
      _lastLocationError = 'Chưa cấp quyền vị trí GPS để bật Live Tracking.';
      notifyListeners();
      return false;
    }

    _isTrackingLocation = true;
    await _locationService.listenLocationUpdates(
      onLocation: (pos) {
        _currentPosition = pos;
        _trackingHistory.insert(0, pos);
        if (_trackingHistory.length > 50) {
          _trackingHistory.removeLast();
        }
        if (!pos.isMocked) {
          _socketService.emitLocationUpdate(userId, pos);
        }
        notifyListeners();
      },
    );
    _statusMessage = 'Đang bật Live Tracking tọa độ GPS liên tục.';
    notifyListeners();
    return true;
  }

  /// Kết nối lại Socket.IO khi người dùng đổi URL Server
  void reconnectSocket() {
    _socketService.disconnect();
    _socketService.connect(AppConfig.socketUrl, onUpdate: notifyListeners);
    AppConfig.fetchOfficeConfig().then((_) => notifyListeners());
    notifyListeners();
  }

  /// Reset lại chu trình Liveness để quét khuôn mặt mới
  void resetLiveness() {
    _isLivenessVerified = false;
    _latestFaceEmbedding = null;
    _faceDetectorService.resetLiveness();
    _statusMessage = 'Hãy nhìn vào camera và CHỚP MẮT để xác thực';
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _faceDetectorService.dispose();
    _faceAIService.dispose();
    _locationService.dispose();
    _socketService.disconnect();
    super.dispose();
  }
}

