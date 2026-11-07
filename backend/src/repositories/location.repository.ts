import { LiveLocationModel } from '../database/models/LiveLocation.model';
import { LiveLocationRecord } from '../types';
import { isMongoConnected } from '../database/mongo';

export class LocationRepository {
  private memLocations: Map<string, LiveLocationRecord> = new Map();

  async upsertLocation(record: LiveLocationRecord): Promise<void> {
    this.memLocations.set(record.userId, record);

    if (isMongoConnected()) {
      try {
        await LiveLocationModel.findOneAndUpdate(
          { userId: record.userId },
          { $set: record },
          { upsert: true }
        );
      } catch (err) {
        console.error('[LocationRepository] Lỗi lưu LiveLocation vào MongoDB Atlas:', err);
      }
    }
  }

  async findAll(): Promise<LiveLocationRecord[]> {
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
        console.error('[LocationRepository] Lỗi đọc LiveLocations từ MongoDB Atlas:', err);
      }
    }

    return Array.from(this.memLocations.values());
  }

  async findByUserId(userId: string): Promise<LiveLocationRecord | null> {
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
        console.error('[LocationRepository] Lỗi đọc User LiveLocation từ MongoDB Atlas:', err);
      }
    }

    return this.memLocations.get(userId) || null;
  }
}

export const locationRepository = new LocationRepository();

