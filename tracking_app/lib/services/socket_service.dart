import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../models/location_data.dart';

class SocketService {
  IO.Socket? _socket;
  bool _isConnected = false;
  VoidCallback? onStateChanged;

  bool get isConnected => _isConnected;

  void connect(String url, {VoidCallback? onUpdate}) {
    if (onUpdate != null) onStateChanged = onUpdate;
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('[SocketService] Đã kết nối Socket.IO Server: $url');
      onStateChanged?.call();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('[SocketService] Mất kết nối Socket.IO Server');
      onStateChanged?.call();
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('[SocketService] Lỗi kết nối Socket: $err');
      onStateChanged?.call();
    });

    // Đồng bộ cấu hình vị trí & bán kính công ty theo thời gian thực
    _socket!.on('office:config_updated', (data) {
      if (data is Map) {
        if (data['lat'] != null) AppConfig.officeLat = (data['lat'] as num).toDouble();
        if (data['lng'] != null) AppConfig.officeLng = (data['lng'] as num).toDouble();
        if (data['maxRadiusMeters'] != null) {
          AppConfig.officeRadius = (data['maxRadiusMeters'] as num).toDouble();
        }
        if (data['name'] is String && (data['name'] as String).trim().isNotEmpty) {
          AppConfig.officeName = data['name'];
        }
        onStateChanged?.call();
      }
    });
  }

  void emitLocationUpdate(String userId, PositionData position) {
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('location:update', position.toJson(userId));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
