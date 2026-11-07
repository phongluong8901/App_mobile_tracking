export type AttendanceCheckType =
  | 'MORNING_IN'
  | 'MORNING_OUT'
  | 'AFTERNOON_IN'
  | 'AFTERNOON_OUT'
  | 'CHECK_IN'
  | 'CHECK_OUT';

export interface OfficeConfig {
  lat: number;
  lng: number;
  maxRadiusMeters: number;
  name?: string;
  morningStart?: string;   // Mặc định "08:00"
  morningEnd?: string;     // Mặc định "12:00"
  afternoonStart?: string; // Mặc định "13:30"
  afternoonEnd?: string;   // Mặc định "17:00"
  workStart?: string;      // Tương thích cũ "08:00"
  workEnd?: string;        // Tương thích cũ "17:00"
}

export interface UserFaceRecord {
  userId: string;
  name: string;
  faceEmbedding: number[];
  registeredAt: string;
}

export interface AttendanceRecord {
  id: number;
  userId: string;
  name?: string;
  type?: AttendanceCheckType;
  shiftStatus?: 'ON_TIME' | 'LATE' | 'EARLY_LEAVE' | 'OVERTIME';
  lateMinutes?: number;
  earlyLeaveMinutes?: number;
  workedHours?: number;
  workUnits?: number; // Số công của ca (0.5 công mỗi buổi, 1.0 công cả ngày)
  lat: number;
  lng: number;
  distance: number;
  similarity: number;
  deviceId?: string;
  timestamp: string;
  status: 'SUCCESS' | 'REJECTED';
  rejectionReason?: string;
}

export interface LiveLocationRecord {
  userId: string;
  lat: number;
  lng: number;
  speed?: number;
  timestamp: string;
}

export interface CheckInInput {
  userId: string;
  type?: AttendanceCheckType;
  lat: number;
  lng: number;
  isMocked: boolean;
  embedding: number[];
  deviceId?: string;
}

export interface CheckInResult {
  success: boolean;
  message: string;
  data?: AttendanceRecord;
}
