import { AttendanceModel } from '../database/models/Attendance.model';
import { AttendanceRecord } from '../types';
import { isMongoConnected } from '../database/mongo';

export class AttendanceRepository {
  private memLogs: AttendanceRecord[] = [];

  async create(record: AttendanceRecord): Promise<AttendanceRecord> {
    this.memLogs.push(record);

    if (isMongoConnected()) {
      try {
        const mongoWrite = AttendanceModel.create(record);
        const timeout = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('MongoDB Attendance create timeout')), 3000)
        );
        await Promise.race([mongoWrite, timeout]);
      } catch (err: any) {
        console.error('[AttendanceRepository] Cảnh báo lưu điểm danh vào MongoDB Atlas:', err.message);
      }
    }

    return record;
  }

  async findUserDayLogs(userId: string, datePrefix: string): Promise<AttendanceRecord[]> {
    if (isMongoConnected()) {
      try {
        const q = AttendanceModel.find({
          userId,
          status: 'SUCCESS',
          timestamp: { $regex: `^${datePrefix}` }
        })
          .sort({ id: 1 })
          .maxTimeMS(2500)
          .lean();

        const timeout = new Promise<any[]>((_, reject) =>
          setTimeout(() => reject(new Error('MongoDB query timeout')), 2500)
        );
        const docs: any[] = await Promise.race([q, timeout]);
        if (docs && docs.length > 0) {
          return docs.map((d) => this.mapDoc(d));
        }
      } catch (_) {}
    }

    return this.memLogs
      .filter(
        (r) =>
          r.userId === userId &&
          r.status === 'SUCCESS' &&
          r.timestamp.startsWith(datePrefix)
      )
      .sort((a, b) => a.id - b.id);
  }

  async findFirstCheckInToday(userId: string, datePrefix: string): Promise<AttendanceRecord | null> {
    const dayLogs = await this.findUserDayLogs(userId, datePrefix);
    const found = dayLogs.find(
      (r) => r.type === 'MORNING_IN' || r.type === 'AFTERNOON_IN' || r.type === 'CHECK_IN' || !r.type
    );
    return found || null;
  }

  async findLogs(filter?: {
    userId?: string;
    limit?: number;
  }): Promise<AttendanceRecord[]> {
    if (isMongoConnected()) {
      try {
        const query: Record<string, unknown> = {};
        if (filter?.userId) {
          query.userId = filter.userId;
        }

        let q = AttendanceModel.find(query).sort({ id: -1 }).maxTimeMS(3000);
        if (filter?.limit && filter.limit > 0) {
          q = q.limit(filter.limit);
        }

        const timeout = new Promise<any[]>((_, reject) =>
          setTimeout(() => reject(new Error('MongoDB Attendance query timeout')), 3000)
        );

        const docs = await Promise.race([q.lean(), timeout]);
        return docs.map((doc: any) => this.mapDoc(doc));
      } catch (err: any) {
        console.error('[AttendanceRepository] Cảnh báo truy vấn logs từ MongoDB Atlas:', err.message);
      }
    }

    let result = [...this.memLogs];
    if (filter?.userId) {
      result = result.filter((r) => r.userId === filter.userId);
    }
    result.sort((a, b) => b.id - a.id);
    if (filter?.limit && filter.limit > 0) {
      result = result.slice(0, filter.limit);
    }
    return result;
  }

  private mapDoc(doc: any): AttendanceRecord {
    return {
      id: doc.id,
      userId: doc.userId,
      name: doc.name,
      type: doc.type || 'MORNING_IN',
      shiftStatus: doc.shiftStatus || 'ON_TIME',
      lateMinutes: doc.lateMinutes || 0,
      earlyLeaveMinutes: doc.earlyLeaveMinutes || 0,
      workedHours: doc.workedHours || 0,
      workUnits: doc.workUnits || 0,
      lat: doc.lat,
      lng: doc.lng,
      distance: doc.distance,
      similarity: doc.similarity,
      deviceId: doc.deviceId,
      timestamp: doc.timestamp,
      status: doc.status,
      rejectionReason: doc.rejectionReason
    };
  }
}

export const attendanceRepository = new AttendanceRepository();
