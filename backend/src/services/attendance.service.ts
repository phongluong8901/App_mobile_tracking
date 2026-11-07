import { attendanceRepository } from '../repositories/attendance.repository';
import { faceService } from './face.service';
import { geoService } from './geo.service';
import { AttendanceCheckType, AttendanceRecord, CheckInInput, CheckInResult } from '../types';

export class AttendanceService {
  private parseTimeMinutes(hhmm: string, defaultH: number, defaultM: number): number {
    const parts = (hhmm || '').split(':');
    if (parts.length === 2) {
      const h = parseInt(parts[0], 10);
      const m = parseInt(parts[1], 10);
      if (!isNaN(h) && !isNaN(m)) return h * 60 + m;
    }
    return defaultH * 60 + defaultM;
  }

  /**
   * Chuẩn hóa loại chấm công về 4 mốc chuẩn trong ngày:
   * - MORNING_IN: Vào ca sáng (08:00)
   * - MORNING_OUT: Ra nghỉ trưa (12:00)
   * - AFTERNOON_IN: Vào ca chiều (13:30)
   * - AFTERNOON_OUT: Ra ca chiều (17:00)
   */
  private resolveCheckType(rawType: AttendanceCheckType | undefined, curMinutes: number): AttendanceCheckType {
    if (
      rawType === 'MORNING_IN' ||
      rawType === 'MORNING_OUT' ||
      rawType === 'AFTERNOON_IN' ||
      rawType === 'AFTERNOON_OUT'
    ) {
      return rawType;
    }
    if (rawType === 'CHECK_OUT') {
      return curMinutes < 13 * 60 + 15 ? 'MORNING_OUT' : 'AFTERNOON_OUT';
    }
    if (rawType === 'CHECK_IN') {
      return curMinutes < 12 * 60 ? 'MORNING_IN' : 'AFTERNOON_IN';
    }
    // Tự động nhận diện theo khung giờ hiện tại
    if (curMinutes < 10 * 60 + 30) return 'MORNING_IN';
    if (curMinutes < 12 * 60 + 45) return 'MORNING_OUT';
    if (curMinutes < 15 * 60 + 15) return 'AFTERNOON_IN';
    return 'AFTERNOON_OUT';
  }

  private getActionLabel(type: AttendanceCheckType): string {
    switch (type) {
      case 'MORNING_IN':
        return 'Vào Ca Sáng (08:00)';
      case 'MORNING_OUT':
        return 'Ra Ca Sáng (12:00)';
      case 'AFTERNOON_IN':
        return 'Vào Ca Chiều (13:30)';
      case 'AFTERNOON_OUT':
        return 'Ra Ca Chiều (17:00)';
      case 'CHECK_OUT':
        return 'Ra Ca';
      default:
        return 'Vào Ca';
    }
  }

  async processCheckIn(input: CheckInInput): Promise<CheckInResult> {
    const { userId, lat, lng, isMocked, embedding, deviceId } = input;
    const now = new Date();
    const isoNow = now.toISOString();
    const curMinutes = now.getHours() * 60 + now.getMinutes();

    const checkType: AttendanceCheckType = this.resolveCheckType(input.type, curMinutes);
    const actionLabel = this.getActionLabel(checkType);

    const office = await geoService.getOfficeConfig();

    // 1. Kiểm tra Fake GPS
    if (isMocked === true) {
      const record: AttendanceRecord = {
        id: Date.now(),
        userId,
        type: checkType,
        lat,
        lng,
        distance: 0,
        similarity: 0,
        deviceId,
        timestamp: isoNow,
        status: 'REJECTED',
        rejectionReason: 'Phát hiện ứng dụng giả lập GPS'
      };
      await attendanceRepository.create(record);

      return {
        success: false,
        message: `Từ chối ${actionLabel}: Phát hiện đang sử dụng Fake GPS!`,
        data: record
      };
    }

    // 2. Kiểm tra tài khoản đã đăng ký khuôn mặt chưa
    const user = await faceService.getUser(userId);
    if (!user) {
      const record: AttendanceRecord = {
        id: Date.now(),
        userId,
        type: checkType,
        lat,
        lng,
        distance: 0,
        similarity: 0,
        deviceId,
        timestamp: isoNow,
        status: 'REJECTED',
        rejectionReason: 'Tài khoản chưa đăng ký dữ liệu khuôn mặt gốc'
      };
      await attendanceRepository.create(record);

      return {
        success: false,
        message: `Từ chối ${actionLabel}: Tài khoản chưa đăng ký khuôn mặt gốc.`,
        data: record
      };
    }

    // 3. Kiểm tra khoảng cách địa lý (Haversine Geofencing)
    const distance = geoService.calculateDistance(lat, lng, office.lat, office.lng);

    if (distance > office.maxRadiusMeters) {
      const record: AttendanceRecord = {
        id: Date.now(),
        userId,
        name: user.name,
        type: checkType,
        lat,
        lng,
        distance,
        similarity: 0,
        deviceId,
        timestamp: isoNow,
        status: 'REJECTED',
        rejectionReason: `Ngoài vùng chấm công (${distance}m > ${office.maxRadiusMeters}m)`
      };
      await attendanceRepository.create(record);

      return {
        success: false,
        message: `Từ chối ${actionLabel}: Cách công ty ${distance}m (tối đa ${office.maxRadiusMeters}m).`,
        data: record
      };
    }

    // 4. Đối chiếu vector khuôn mặt (Cosine Similarity)
    const verification = await faceService.verifyFace(userId, embedding);

    if (!verification.matched) {
      const record: AttendanceRecord = {
        id: Date.now(),
        userId,
        name: user.name,
        type: checkType,
        lat,
        lng,
        distance,
        similarity: verification.similarity,
        deviceId,
        timestamp: isoNow,
        status: 'REJECTED',
        rejectionReason: 'Khuôn mặt không trùng khớp với dữ liệu đăng ký'
      };
      await attendanceRepository.create(record);

      return {
        success: false,
        message: `Từ chối ${actionLabel}: Khuôn mặt không khớp (${(verification.similarity * 100).toFixed(1)}%).`,
        data: record
      };
    }

    // 5. Tính toán Bảng Chấm Công Thật 2 Buổi:
    // Ca Sáng: 08:00 - 12:00 (4.0h = 0.5 công)
    // Ca Chiều: 13:30 - 17:00 (3.5h = 0.5 công)
    const morningStartMin = this.parseTimeMinutes(office.morningStart || '08:00', 8, 0);
    const morningEndMin = this.parseTimeMinutes(office.morningEnd || '12:00', 12, 0);
    const afternoonStartMin = this.parseTimeMinutes(office.afternoonStart || '13:30', 13, 30);
    const afternoonEndMin = this.parseTimeMinutes(office.afternoonEnd || '17:00', 17, 0);

    let shiftStatus: 'ON_TIME' | 'LATE' | 'EARLY_LEAVE' | 'OVERTIME' = 'ON_TIME';
    let lateMinutes = 0;
    let earlyLeaveMinutes = 0;
    let workedHours = 0;
    let workUnits = 0;
    let shiftNote = 'Đúng giờ';

    const datePrefix = isoNow.substring(0, 10);
    const dayLogs = await attendanceRepository.findUserDayLogs(userId, datePrefix);

    if (checkType === 'MORNING_IN') {
      if (curMinutes > morningStartMin + 5) {
        shiftStatus = 'LATE';
        lateMinutes = curMinutes - morningStartMin;
        shiftNote = `Đi muộn ca sáng ${lateMinutes} phút`;
      } else {
        shiftStatus = 'ON_TIME';
        shiftNote = 'Vào ca sáng đúng giờ (08:00)';
      }
    } else if (checkType === 'MORNING_OUT') {
      const morningIn = dayLogs.find((r) => r.type === 'MORNING_IN' || r.type === 'CHECK_IN');
      if (morningIn) {
        const inTime = new Date(morningIn.timestamp).getTime();
        const rawHours = Math.max(0.5, (now.getTime() - inTime) / (1000 * 3600));
        workedHours = Number(Math.min(4.5, rawHours).toFixed(2));
      } else {
        workedHours = 4.0;
      }
      workUnits = 0.5;

      if (curMinutes < morningEndMin - 5) {
        shiftStatus = 'EARLY_LEAVE';
        earlyLeaveMinutes = morningEndMin - curMinutes;
        shiftNote = `Nghỉ trưa sớm ${earlyLeaveMinutes}p • +0.5 công (${workedHours}h)`;
      } else {
        shiftStatus = 'ON_TIME';
        shiftNote = `Hoàn thành Ca Sáng (+0.5 công • ${workedHours}h)`;
      }
    } else if (checkType === 'AFTERNOON_IN') {
      if (curMinutes > afternoonStartMin + 5) {
        shiftStatus = 'LATE';
        lateMinutes = curMinutes - afternoonStartMin;
        shiftNote = `Đi muộn ca chiều ${lateMinutes} phút`;
      } else {
        shiftStatus = 'ON_TIME';
        shiftNote = 'Vào ca chiều đúng giờ (13:30)';
      }
    } else if (checkType === 'AFTERNOON_OUT') {
      const afternoonIn = dayLogs.find((r) => r.type === 'AFTERNOON_IN');
      const morningIn = dayLogs.find((r) => r.type === 'MORNING_IN' || r.type === 'CHECK_IN');
      const hasMorningOut = dayLogs.some((r) => r.type === 'MORNING_OUT');

      if (afternoonIn) {
        const inTime = new Date(afternoonIn.timestamp).getTime();
        const rawHours = Math.max(0.5, (now.getTime() - inTime) / (1000 * 3600));
        workedHours = Number(Math.min(6.0, rawHours).toFixed(2));
        workUnits = 0.5;
      } else if (morningIn && !hasMorningOut) {
        // Trường hợp làm thông ca từ sáng đến chiều không bấm nghỉ trưa
        const inTime = new Date(morningIn.timestamp).getTime();
        const rawHours = Math.max(1.0, (now.getTime() - inTime) / (1000 * 3600) - 1.5);
        workedHours = Number(Math.min(9.5, rawHours).toFixed(2));
        workUnits = 1.0;
      } else {
        workedHours = 3.5;
        workUnits = 0.5;
      }

      if (curMinutes < afternoonEndMin - 5) {
        shiftStatus = 'EARLY_LEAVE';
        earlyLeaveMinutes = afternoonEndMin - curMinutes;
        shiftNote = `Về sớm ${earlyLeaveMinutes}p • +${workUnits} công (${workedHours}h)`;
      } else if (curMinutes > afternoonEndMin + 30) {
        shiftStatus = 'OVERTIME';
        shiftNote = `Tăng ca • +${workUnits} công (${workedHours}h)`;
      } else {
        shiftStatus = 'ON_TIME';
        shiftNote = `Hoàn thành Ca Chiều (+${workUnits} công • ${workedHours}h)`;
      }
    }

    const record: AttendanceRecord = {
      id: Date.now(),
      userId,
      name: user.name,
      type: checkType,
      shiftStatus,
      lateMinutes,
      earlyLeaveMinutes,
      workedHours,
      workUnits,
      lat,
      lng,
      distance,
      similarity: verification.similarity,
      deviceId,
      timestamp: isoNow,
      status: 'SUCCESS'
    };
    await attendanceRepository.create(record);

    return {
      success: true,
      message: `${actionLabel}: ${shiftNote} • FaceID ${(verification.similarity * 100).toFixed(1)}%`,
      data: record
    };
  }

  async getLogs(filter?: {
    userId?: string;
    limit?: number;
  }): Promise<AttendanceRecord[]> {
    return await attendanceRepository.findLogs(filter);
  }
}

export const attendanceService = new AttendanceService();
