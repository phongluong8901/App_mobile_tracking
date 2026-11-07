import mongoose from 'mongoose';
import { MONGODB_URI, DB_NAME } from '../config';

// Tắt hoàn toàn buffering của Mongoose để không bao giờ bị treo request nếu Atlas chậm
mongoose.set('bufferCommands', false);
mongoose.set('bufferTimeoutMS', 4000);

let isConnected = false;

export async function connectMongo(): Promise<void> {
  if (isConnected && mongoose.connection.readyState === 1) {
    return;
  }

  try {
    console.error(`[MONGODB] Đang kết nối tới MongoDB Atlas (${DB_NAME})...`);
    await mongoose.connect(MONGODB_URI, {
      dbName: DB_NAME,
      serverSelectionTimeoutMS: 5000, // Timeout 5 giây nếu không kết nối được
      connectTimeoutMS: 5000,
      autoIndex: true
    });

    isConnected = true;
    console.error(`[MONGODB] Đã kết nối thành công tới MongoDB Atlas (Database: ${DB_NAME})`);

    mongoose.connection.on('error', (err) => {
      console.error('[MONGODB ERROR]', err);
    });

    mongoose.connection.on('disconnected', () => {
      console.error('[MONGODB DISCONNECTED] Mất kết nối tới MongoDB Atlas');
      isConnected = false;
    });
  } catch (error: any) {
    isConnected = false;
    console.error('[MONGODB CONNECTION FAILED] Lỗi kết nối Atlas:', error.message);
    console.error('[MONGODB GỢI Ý KHẮC PHỤC]:');
    console.error('1. Đăng nhập https://cloud.mongodb.com -> chọn Cluster "trackingflutter"');
    console.error('2. Vào mục "Network Access" -> "Add IP Address" -> chọn "Allow Access From Anywhere" (0.0.0.0/0)');
    console.error('3. Trong lúc chờ kết nối Atlas, hệ thống TỰ ĐỘNG LƯU IN-MEMORY đảm bảo app không bao giờ bị gián đoạn hay mất dữ liệu.');
  }
}

export async function disconnectMongo(): Promise<void> {
  if (isConnected) {
    await mongoose.disconnect();
    isConnected = false;
    console.error('[MONGODB] Đã ngắt kết nối.');
  }
}

export function isMongoConnected(): boolean {
  return isConnected && mongoose.connection.readyState === 1;
}
