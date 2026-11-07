import dotenv from 'dotenv';
import { OfficeConfig } from './types';

// Nạp biến môi trường từ .env
dotenv.config();

export const MONGODB_URI =
  process.env.MONGODB_URI ||
  'mongodb+srv://phongluong3366_db_user:aUhmjz2NzuVuaFL2@trackingflutter.vuzz1uv.mongodb.net/attendance_tracking?retryWrites=true&w=majority&appName=trackingflutter';

export const MONGODB_USERNAME = process.env.MONGODB_USERNAME || 'phongluong3366_db_user';
export const MONGODB_PASSWORD = process.env.MONGODB_PASSWORD || 'aUhmjz2NzuVuaFL2';
export const DB_NAME = process.env.DB_NAME || 'attendance_tracking';

// Cấu hình tọa độ trụ sở công ty (Chuẩn đồng bộ với BACKEND_INTEGRATION_SPEC)
export const DEFAULT_OFFICE_CONFIG: OfficeConfig = {
  lat: process.env.COMPANY_LAT
    ? parseFloat(process.env.COMPANY_LAT)
    : process.env.OFFICE_LAT
    ? parseFloat(process.env.OFFICE_LAT)
    : 21.028511,
  lng: process.env.COMPANY_LNG
    ? parseFloat(process.env.COMPANY_LNG)
    : process.env.OFFICE_LNG
    ? parseFloat(process.env.OFFICE_LNG)
    : 105.854444,
  maxRadiusMeters: process.env.MAX_ALLOWED_DISTANCE_METERS
    ? parseFloat(process.env.MAX_ALLOWED_DISTANCE_METERS)
    : process.env.OFFICE_MAX_RADIUS_METERS
    ? parseFloat(process.env.OFFICE_MAX_RADIUS_METERS)
    : 200
};

// Ngưỡng tối thiểu khớp khuôn mặt: 80% (0.80)
export const FACE_MATCH_THRESHOLD = process.env.MIN_FACE_SIMILARITY
  ? parseFloat(process.env.MIN_FACE_SIMILARITY)
  : process.env.FACE_MATCH_THRESHOLD
  ? parseFloat(process.env.FACE_MATCH_THRESHOLD)
  : 0.80;

export const MOBILE_FACENET_EMBEDDING_DIM = 192;
