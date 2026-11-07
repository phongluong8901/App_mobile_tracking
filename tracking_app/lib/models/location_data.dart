class PositionData {
  final double latitude;
  final double longitude;
  final double speed;
  final bool isMocked;
  final DateTime timestamp;

  PositionData({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.isMocked,
    required this.timestamp,
  });

  Map<String, dynamic> toJson(String userId) {
    return {
      'userId': userId,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

