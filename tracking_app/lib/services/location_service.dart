import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';

enum LocationPermissionStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

class LocationService {
  StreamSubscription<Position>? _positionStream;

  /// Kiểm tra trạng thái và hiển thị popup xin quyền GPS trên điện thoại
  Future<LocationPermissionStatus> requestPermissionWithStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionStatus.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }

    return LocationPermissionStatus.granted;
  }

  /// Mở màn hình bật GPS của điện thoại
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Mở màn hình Cài đặt quyền của ứng dụng
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Kiểm tra và xin quyền GPS (ném lỗi chi tiết nếu chưa cấp quyền)
  Future<void> checkAndRequestPermissions() async {
    final status = await requestPermissionWithStatus();

    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        throw Exception('Định vị GPS trên điện thoại đang TẮT. Vui lòng bật GPS!');
      case LocationPermissionStatus.denied:
        throw Exception('Bạn đã từ chối quyền truy cập vị trí GPS.');
      case LocationPermissionStatus.deniedForever:
        throw Exception(
          'Quyền vị trí bị chặn vĩnh viễn. Hãy bấm "Mở Cài Đặt" để cấp quyền Vị trí cho ứng dụng.',
        );
      case LocationPermissionStatus.granted:
        break;
    }
  }

  /// Lấy vị trí GPS hiện tại kèm kiểm tra Fake GPS (có fallback trong nhà)
  Future<PositionData> getCurrentPosition() async {
    await checkAndRequestPermissions();

    Position? position;

    try {
      // Ưu tiên độ chính xác cao (GPS vệ tinh + WiFi)
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on TimeoutException {
      // Nếu ở trong nhà sóng vệ tinh yếu, fallback sang độ chính xác trung bình (WiFi/Trạm phát sóng)
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null) {
      throw Exception('Không thu được tín hiệu GPS. Hãy bật WiFi/4G và thử lại.');
    }

    return PositionData(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      isMocked: position.isMocked,
      timestamp: DateTime.now(),
    );
  }

  /// Lắng nghe tọa độ GPS liên tục khi di chuyển (mặc định mỗi 10m)
  Future<void> listenLocationUpdates({
    required Function(PositionData) onLocation,
    int distanceFilterMeters = 10,
  }) async {
    await checkAndRequestPermissions();
    stopListening();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position pos) {
      onLocation(
        PositionData(
          latitude: pos.latitude,
          longitude: pos.longitude,
          speed: pos.speed,
          isMocked: pos.isMocked,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  /// Tính khoảng cách giữa 2 điểm tọa độ theo mét (Haversine chuẩn)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  void stopListening() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void dispose() {
    stopListening();
  }
}
