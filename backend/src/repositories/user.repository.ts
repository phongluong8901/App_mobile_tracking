import { UserModel } from '../database/models/User.model';
import { UserFaceRecord } from '../types';
import { isMongoConnected } from '../database/mongo';

export class UserRepository {
  private memUsers: Map<string, UserFaceRecord> = new Map();

  async saveUser(
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

    // 1. Luôn lưu ngay vào bộ nhớ đệm in-memory trước để đảm bảo dữ liệu có ngay
    this.memUsers.set(userId, record);
    console.log(`[UserRepository] Đã lưu in-memory cho user: ${userId} (${name})`);

    // 2. Đồng bộ vào MongoDB Atlas nếu có kết nối (có timeout 3s chống treo)
    if (isMongoConnected()) {
      try {
        const mongoWrite = UserModel.findOneAndUpdate(
          { userId },
          {
            $set: {
              userId,
              name,
              faceEmbedding,
              registeredAt: record.registeredAt
            }
          },
          { upsert: true, new: true, maxTimeMS: 3000 }
        );

        const timeout = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('MongoDB save timeout sau 3s')), 3000)
        );

        await Promise.race([mongoWrite, timeout]);
        console.log(`[UserRepository] Đã đồng bộ thành công vào MongoDB Atlas cho: ${userId}`);
      } catch (err: any) {
        console.error('[UserRepository] Cảnh báo: Lỗi ghi MongoDB Atlas (vẫn an toàn vì đã lưu in-memory):', err.message);
      }
    } else {
      console.warn(`[UserRepository] MongoDB Atlas chưa kết nối, dữ liệu ${userId} đang được giữ an toàn trong in-memory store.`);
    }

    return record;
  }

  async findByUserId(userId: string): Promise<UserFaceRecord | null> {
    // Ưu tiên đọc từ MongoDB Atlas nếu có kết nối
    if (isMongoConnected()) {
      try {
        const mongoRead = UserModel.findOne({ userId }).maxTimeMS(3000).lean();
        const timeout = new Promise<null>((_, reject) =>
          setTimeout(() => reject(new Error('MongoDB read timeout sau 3s')), 3000)
        );

        const doc: any = await Promise.race([mongoRead, timeout]);
        if (doc) {
          const rec: UserFaceRecord = {
            userId: doc.userId,
            name: doc.name,
            faceEmbedding: doc.faceEmbedding,
            registeredAt: doc.registeredAt
          };
          this.memUsers.set(userId, rec);
          return rec;
        }
      } catch (err: any) {
        console.error('[UserRepository] Cảnh báo đọc Atlas:', err.message);
      }
    }

    // Fallback in-memory
    return this.memUsers.get(userId) || null;
  }

  async findAll(): Promise<Omit<UserFaceRecord, 'faceEmbedding'>[]> {
    if (isMongoConnected()) {
      try {
        const docs = await UserModel.find({}, { faceEmbedding: 0 }).maxTimeMS(3000).lean();
        return docs.map((doc) => ({
          userId: doc.userId,
          name: doc.name,
          registeredAt: doc.registeredAt
        }));
      } catch (err) {
        console.error('[UserRepository] Lỗi lấy danh sách User từ MongoDB Atlas:', err);
      }
    }

    return Array.from(this.memUsers.values()).map(
      ({ faceEmbedding, ...rest }) => rest
    );
  }
}

export const userRepository = new UserRepository();
