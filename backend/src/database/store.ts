import {
  OfficeConfig,
  UserFaceRecord,
  AttendanceRecord,
  LiveLocationRecord
} from '../types';
import { DEFAULT_OFFICE_CONFIG } from '../config';
import { UserModel } from './models/User.model';
import { AttendanceModel } from './models/Attendance.model';
import { LiveLocationModel } from './models/LiveLocation.model';
import { OfficeConfigModel } from './models/OfficeConfig.model';
import { isMongoConnected } from './mongo';

export class Store {
  // In-memory fallback / cache
  private memOfficeConfig: OfficeConfig = { ...DEFAULT_OFFICE_CONFIG };
  private memUsers: Map<string, UserFaceRecord> = new Map();
  private memAttendanceLogs: AttendanceRecord[] = [];
  private memLiveLocations: Map<string, LiveLocationRecord> = new Map();

  // --- Office Config ---
  async getOfficeConfig(): Promise<OfficeConfig> {
    if (isMongoConnected()) {
      try {
        const found = await OfficeConfigModel.findOne({ key: 'primary' }).lean();
        if (found) {
          return {
            lat: found.lat,
            lng: found.lng,
            maxRadiusMeters: found.maxRadiusMeters
          };
        }
      } catch (err) {
        console.error('[STORE] Lỗi đọc OfficeConfig từ MongoDB:', err);
      }
    }
    return { ...this.memOfficeConfig };
  }

  async updateOfficeConfig(config: Partial<OfficeConfig>): Promise<OfficeConfig> {
    this.memOfficeConfig = {
      ...this.memOfficeConfig,
      ...config
    };

    if (isMongoConnected()) {
      try {
        await OfficeConfigModel.findOneAndUpdate(
          { key: 'primary' },
          {
            $set: {
              key: 'primary',
              lat: this.memOfficeConfig.lat,
              lng: this.memOfficeConfig.lng,
              maxRadiusMeters: this.memOfficeConfig.maxRadiusMeters
            }
          },
          { upsert: true, new: true }
        );
      } catch (err) {
        console.error('[STORE] Lỗi ghi OfficeConfig vào MongoDB:', err);
      }
    }

    return { ...this.memOfficeConfig };
  }

  // --- Users ---
  async registerUser(
    userId: string,
    name: string,
    faceEmbedding: number[]
  ): Promise<UserFaceRecord> {
    const record: UserFaceRecord = {
      userId,
      name,
      faceEmbedding,
      registeredAt: new Date().toISOString()
    };

    this.memUsers.set(userId, record);

    if (isMongoConnected()) {
      try {
        await UserModel.findOneAndUpdate(
          { userId },
          {
            $set: {
              userId,
              name,
              faceEmbedding,
              registeredAt: record.registeredAt
            }
          },
          { upsert: true, new: true }
        );
      } catch (err) {
        console.error('[STORE] Lỗi lưu User vào MongoDB:', err);
      }
    }

    return record;
  }

  async getUser(userId: string): Promise<UserFaceRecord | undefined> {
    if (isMongoConnected()) {
      try {
        const userDoc = await UserModel.findOne({ userId }).lean();
        if (userDoc) {
          return {
            userId: userDoc.userId,
            name: userDoc.name,
            faceEmbedding: userDoc.faceEmbedding,
            registeredAt: userDoc.registeredAt
          };
        }
      } catch (err) {
        console.error('[STORE] Lỗi tìm User từ MongoDB:', err);
      }
    }
    return this.memUsers.get(userId);
  }

  async getAllUsers(): Promise<Omit<UserFaceRecord, 'faceEmbedding'>[]> {
    if (isMongoConnected()) {
      try {
        const users = await UserModel.find({}, { faceEmbedding: 0 }).lean();
        return users.map((u) => ({
          userId: u.userId,
          name: u.name,
          registeredAt: u.registeredAt
        }));
      } catch (err) {
        console.error('[STORE] Lỗi đọc danh sách User từ MongoDB:', err);
      }
    }
    return Array.from(this.memUsers.values()).map(({ faceEmbedding, ...rest }) => rest);
  }

  // --- Attendance ---
  async addAttendanceLog(log: AttendanceRecord): Promise<void> {
    this.memAttendanceLogs.push(log);

    if (isMongoConnected()) {
      try {
        await AttendanceModel.create(log);
      } catch (err) {
        console.error('[STORE] Lỗi lưu AttendanceLog vào MongoDB:', err);
      }
    }
  }

  async getAttendanceLogs(filter?: {
    userId?: string;
    limit?: number;
  }): Promise<AttendanceRecord[]> {
    if (isMongoConnected()) {
      try {
        const query: Record<string, unknown> = {};
        if (filter?.userId) {
          query.userId = filter.userId;
        }

        let q = AttendanceModel.find(query).sort({ id: -1 });
        if (filter?.limit && filter.limit > 0) {
          q = q.limit(filter.limit);
        }

        const docs = await q.lean();
        return docs.map((doc) => ({
          id: doc.id,
          userId: doc.userId,
          name: doc.name,
          lat: doc.lat,
          lng: doc.lng,
          distance: doc.distance,
          similarity: doc.similarity,
          deviceId: doc.deviceId,
          timestamp: doc.timestamp,
          status: doc.status,
          rejectionReason: doc.rejectionReason
        }));
      } catch (err) {
        console.error('[STORE] Lỗi đọc AttendanceLogs từ MongoDB:', err);
      }
    }

    let result = [...this.memAttendanceLogs];
    if (filter?.userId) {
      result = result.filter((r) => r.userId === filter.userId);
    }
    result.sort((a, b) => b.id - a.id);
    if (filter?.limit && filter.limit > 0) {
      result = result.slice(0, filter.limit);
    }
    return result;
  }

  // --- Live Location ---
  async updateLiveLocation(record: LiveLocationRecord): Promise<void> {
    this.memLiveLocations.set(record.userId, record);

    if (isMongoConnected()) {
      try {
        await LiveLocationModel.findOneAndUpdate(
          { userId: record.userId },
          { $set: record },
          { upsert: true }
        );
      } catch (err) {
        console.error('[STORE] Lỗi cập nhật LiveLocation vào MongoDB:', err);
      }
    }
  }

  async getLiveLocations(): Promise<LiveLocationRecord[]> {
    if (isMongoConnected()) {
      try {
        const docs = await LiveLocationModel.find().lean();
        return docs.map((doc) => ({
          userId: doc.userId,
          lat: doc.lat,
          lng: doc.lng,
          speed: doc.speed,
          timestamp: doc.timestamp
        }));
      } catch (err) {
        console.error('[STORE] Lỗi đọc LiveLocations từ MongoDB:', err);
      }
    }
    return Array.from(this.memLiveLocations.values());
  }

  async getUserLiveLocation(userId: string): Promise<LiveLocationRecord | undefined> {
    if (isMongoConnected()) {
      try {
        const doc = await LiveLocationModel.findOne({ userId }).lean();
        if (doc) {
          return {
            userId: doc.userId,
            lat: doc.lat,
            lng: doc.lng,
            speed: doc.speed,
            timestamp: doc.timestamp
          };
        }
      } catch (err) {
        console.error('[STORE] Lỗi đọc LiveLocation User từ MongoDB:', err);
      }
    }
    return this.memLiveLocations.get(userId);
  }
}

export const store = new Store();
