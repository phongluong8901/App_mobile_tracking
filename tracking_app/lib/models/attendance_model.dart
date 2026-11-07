class AttendanceRecordModel {
  final int id;
  final String userId;
  final String? name;
  final String type; // 'MORNING_IN' | 'MORNING_OUT' | 'AFTERNOON_IN' | 'AFTERNOON_OUT' | 'CHECK_IN' | 'CHECK_OUT'
  final String shiftStatus; // 'ON_TIME' | 'LATE' | 'EARLY_LEAVE' | 'OVERTIME'
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final double workedHours;
  final double workUnits;
  final double lat;
  final double lng;
  final int distance;
  final double similarity;
  final String? deviceId;
  final String timestamp;
  final String status;
  final String? rejectionReason;

  AttendanceRecordModel({
    required this.id,
    required this.userId,
    this.name,
    this.type = 'MORNING_IN',
    this.shiftStatus = 'ON_TIME',
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.workedHours = 0.0,
    this.workUnits = 0.0,
    required this.lat,
    required this.lng,
    required this.distance,
    required this.similarity,
    this.deviceId,
    required this.timestamp,
    required this.status,
    this.rejectionReason,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString(),
      type: json['type']?.toString() ?? 'MORNING_IN',
      shiftStatus: json['shiftStatus']?.toString() ?? 'ON_TIME',
      lateMinutes: (json['lateMinutes'] as num?)?.toInt() ?? 0,
      earlyLeaveMinutes: (json['earlyLeaveMinutes'] as num?)?.toInt() ?? 0,
      workedHours: (json['workedHours'] as num?)?.toDouble() ?? 0.0,
      workUnits: (json['workUnits'] as num?)?.toDouble() ?? 0.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toInt() ?? 0,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      deviceId: json['deviceId']?.toString(),
      timestamp: json['timestamp']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'shiftStatus': shiftStatus,
      'lateMinutes': lateMinutes,
      'earlyLeaveMinutes': earlyLeaveMinutes,
      'workedHours': workedHours,
      'workUnits': workUnits,
      'lat': lat,
      'lng': lng,
      'distance': distance,
      'similarity': similarity,
      'deviceId': deviceId,
      'timestamp': timestamp,
      'status': status,
      'rejectionReason': rejectionReason,
    };
  }

  bool get isSuccess => status == 'SUCCESS';

  bool get isCheckOut =>
      type == 'MORNING_OUT' || type == 'AFTERNOON_OUT' || type == 'CHECK_OUT';

  /// Chuẩn hóa về 1 trong 4 mốc ca chuẩn trong ngày dựa trên type hoặc giờ chấm
  String get normalizedSlot {
    if (type == 'MORNING_IN' ||
        type == 'MORNING_OUT' ||
        type == 'AFTERNOON_IN' ||
        type == 'AFTERNOON_OUT') {
      return type;
    }
    final dt = localDateTime;
    final mins = dt != null ? dt.hour * 60 + dt.minute : 480;
    if (type == 'CHECK_OUT') {
      return mins <= 13 * 60 + 15 ? 'MORNING_OUT' : 'AFTERNOON_OUT';
    }
    return mins < 12 * 60 ? 'MORNING_IN' : 'AFTERNOON_IN';
  }

  DateTime? get localDateTime {
    try {
      return DateTime.parse(timestamp).toLocal();
    } catch (_) {
      return null;
    }
  }

  String get shortTime {
    final dt = localDateTime;
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get typeLabel {
    switch (normalizedSlot) {
      case 'MORNING_IN':
        return 'Vào Ca Sáng (08:00)';
      case 'MORNING_OUT':
        return 'Ra Nghỉ Trưa (12:00)';
      case 'AFTERNOON_IN':
        return 'Vào Ca Chiều (13:30)';
      case 'AFTERNOON_OUT':
        return 'Ra Ca Chiều (17:00)';
      default:
        return isCheckOut ? 'Ra Ca' : 'Vào Ca';
    }
  }

  String get shortSlotLabel {
    switch (normalizedSlot) {
      case 'MORNING_IN':
        return 'Vào Sáng 08:00';
      case 'MORNING_OUT':
        return 'Ra Trưa 12:00';
      case 'AFTERNOON_IN':
        return 'Vào Chiều 13:30';
      case 'AFTERNOON_OUT':
        return 'Ra Chiều 17:00';
      default:
        return 'Chấm công';
    }
  }

  String get shiftLabel {
    if (!isSuccess) return 'Bị từ chối';
    switch (shiftStatus) {
      case 'LATE':
        return 'Đi muộn ${lateMinutes}p';
      case 'EARLY_LEAVE':
        return 'Về sớm ${earlyLeaveMinutes}p';
      case 'OVERTIME':
        return 'Tăng ca';
      default:
        return 'Đúng giờ';
    }
  }
}

/// Trạng thái tổng hợp 1 ngày đi làm trên Lịch Chấm Công
enum DayAttendanceStatus {
  fullOnTime,  // Đủ 1.0 công & Đúng giờ
  lateOrEarly, // Có đi làm nhưng Đi muộn hoặc Về sớm
  halfDay,     // Nửa công (0.5 công) hoặc đang làm dở ca
  absent,      // Ngày làm việc đã qua nhưng vắng mặt
  rejected,    // Chỉ có lượt bị từ chối
  offOrFuture, // Chủ nhật hoặc ngày chưa tới
}

/// Bảng chấm công tổng hợp của 1 ngày (4 mốc: 08:00 - 12:00 và 13:30 - 17:00)
class DailyTimesheetModel {
  final DateTime date;
  final String dateKey; // YYYY-MM-DD
  final AttendanceRecordModel? morningIn;    // 08:00
  final AttendanceRecordModel? morningOut;   // 12:00
  final AttendanceRecordModel? afternoonIn;  // 13:30
  final AttendanceRecordModel? afternoonOut; // 17:00
  final List<AttendanceRecordModel> allRecords;

  DailyTimesheetModel({
    required this.date,
    required this.dateKey,
    this.morningIn,
    this.morningOut,
    this.afternoonIn,
    this.afternoonOut,
    this.allRecords = const [],
  });

  bool get hasMorningShift => morningIn != null || morningOut != null;
  bool get hasAfternoonShift => afternoonIn != null || afternoonOut != null;

  bool get isMorningComplete => morningIn != null && morningOut != null;
  bool get isAfternoonComplete => afternoonIn != null && afternoonOut != null;

  /// Số công trong ngày:
  /// - Ca Sáng (08:00 - 12:00): 0.5 công
  /// - Ca Chiều (13:30 - 17:00): 0.5 công
  /// - Tổng đủ ngày: 1.0 công
  double get workUnits {
    double units = 0.0;
    if (hasMorningShift) units += 0.5;
    if (hasAfternoonShift) units += 0.5;
    return units;
  }

  /// Tổng số giờ làm việc trong ngày (chuẩn 4.0h sáng + 3.5h chiều = 7.5h)
  double get totalWorkedHours {
    double hours = 0.0;
    if (morningOut != null && morningOut!.workedHours > 0) {
      hours += morningOut!.workedHours;
    } else if (hasMorningShift) {
      hours += isMorningComplete ? 4.0 : 2.0;
    }

    if (afternoonOut != null && afternoonOut!.workedHours > 0) {
      hours += afternoonOut!.workedHours;
    } else if (hasAfternoonShift) {
      hours += isAfternoonComplete ? 3.5 : 1.75;
    }
    return double.parse(hours.toStringAsFixed(1));
  }

  int get totalLateMinutes {
    int mins = 0;
    if (morningIn != null) mins += morningIn!.lateMinutes;
    if (afternoonIn != null) mins += afternoonIn!.lateMinutes;
    return mins;
  }

  int get totalEarlyMinutes {
    int mins = 0;
    if (morningOut != null) mins += morningOut!.earlyLeaveMinutes;
    if (afternoonOut != null) mins += afternoonOut!.earlyLeaveMinutes;
    return mins;
  }

  bool get hasLateOrEarly => totalLateMinutes > 0 || totalEarlyMinutes > 0;

  DayAttendanceStatus get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (workUnits >= 1.0) {
      return hasLateOrEarly
          ? DayAttendanceStatus.lateOrEarly
          : DayAttendanceStatus.fullOnTime;
    }
    if (workUnits > 0.0) {
      return hasLateOrEarly
          ? DayAttendanceStatus.lateOrEarly
          : DayAttendanceStatus.halfDay;
    }
    if (allRecords.isNotEmpty) {
      return DayAttendanceStatus.rejected;
    }
    if (target.isAfter(today) || date.weekday == DateTime.sunday) {
      return DayAttendanceStatus.offOrFuture;
    }
    if (target.isBefore(today)) {
      return DayAttendanceStatus.absent;
    }
    return DayAttendanceStatus.offOrFuture;
  }

  String get statusLabel {
    switch (status) {
      case DayAttendanceStatus.fullOnTime:
        return 'Đủ công (1.0)';
      case DayAttendanceStatus.lateOrEarly:
        if (totalLateMinutes > 0 && totalEarlyMinutes > 0) {
          return 'Muộn ${totalLateMinutes}p • Sớm ${totalEarlyMinutes}p';
        }
        if (totalLateMinutes > 0) {
          return 'Đi muộn ${totalLateMinutes}p';
        }
        return 'Về sớm ${totalEarlyMinutes}p';
      case DayAttendanceStatus.halfDay:
        return 'Nửa công (0.5)';
      case DayAttendanceStatus.absent:
        return 'Vắng / Nghỉ';
      case DayAttendanceStatus.rejected:
        return 'Chấm lỗi';
      case DayAttendanceStatus.offOrFuture:
        return date.weekday == DateTime.sunday ? 'Nghỉ CN' : 'Chưa tới';
    }
  }
}
