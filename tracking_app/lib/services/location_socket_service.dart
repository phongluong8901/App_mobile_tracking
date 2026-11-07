import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LocationSocketService {
  IO.Socket? _socket;
  StreamSubscription<Position>? _positionStream;

  // Khởi tạo kết nối Socket.IO tới Server Node.js
  void connectSocket(String serverUrl) {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => print('Đã kết nối Socket.IO Server'));
    _socket!.onDisconnect((_) => print('Mất kết nối Socket.IO'));
  }

  // Xin quyền và lấy vị trí hiện tại (Kèm kiểm tra Fake GPS)
  Future<Position> getCurrentVerifiedPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Vui lòng bật định vị GPS trên điện thoại.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Quyền truy cập vị trí bị từ chối.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí bị chặn vĩnh viễn. Hãy mở trong Cài đặt.');
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return position;
  }

  // Bật chế độ Live Tracking (Bắn tọa độ liên tục khi di chuyển mỗi 10 mét)
  void startLiveTracking(String userId) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Cứ di chuyển 10m thì gửi tọa độ 1 lần
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position pos) {
              if (!pos.isMocked && _socket != null && _socket!.connected) {
                _socket!.emit('location:update', {
                  'userId': userId,
                  'lat': pos.latitude,
                  'lng': pos.longitude,
                  'speed': pos.speed,
                  'timestamp': DateTime.now().toIso8601String(),
                });
              }
            });
  }

  void stopLiveTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  void dispose() {
    stopLiveTracking();
    _socket?.dispose();
  }
}
