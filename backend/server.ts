import express from 'express';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

import { connectMongo, isMongoConnected } from './src/database/mongo';
import { faceController } from './src/controllers/face.controller';
import { attendanceController } from './src/controllers/attendance.controller';
import { trackingController } from './src/controllers/tracking.controller';
import { geoService } from './src/services/geo.service';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Phục vụ giao diện Web Admin Dashboard tĩnh tại http://localhost:3000
app.use(express.static(path.join(__dirname, 'public')));

// Request Logger để theo dõi mọi request từ Flutter gửi lên
app.use((req, res, next) => {
  if (req.url.startsWith('/api') || req.url.startsWith('/health')) {
    const start = Date.now();
    console.log(`[HTTP ${req.method}] ${req.url} - IP: ${req.ip}`);
    res.on('finish', () => {
      console.log(`[HTTP ${req.method}] ${req.url} -> Status ${res.statusCode} (${Date.now() - start}ms)`);
    });
  }
  next();
});

const server = http.createServer(app);
const io = new SocketIOServer(server, {
  cors: { origin: '*' }
});

// Gắn socket cho AttendanceController để phát sự kiện realtime khi điểm danh
attendanceController.setSocketIO(io);

// Thiết lập Socket.IO Controller cho Live Tracking
trackingController.setupSocket(io);

// ==========================================
// REST API ROUTES (CONTROLLER LAYER)
// ==========================================

// Face Recognition Routes
app.post('/api/register-face', (req, res) => faceController.registerFace(req, res));
app.post('/api/verify-face', (req, res) => faceController.verifyFace(req, res));
app.get('/api/users', (req, res) => faceController.getAllUsers(req, res));

// Attendance Routes
app.post('/api/check-in', (req, res) => attendanceController.checkIn(req, res));
app.get('/api/attendance-logs', (req, res) => attendanceController.getLogs(req, res));

// Office Geofence & Location Config Routes
app.get('/api/office-config', async (req, res) => {
  try {
    const config = await geoService.getOfficeConfig();
    return res.json({ success: true, data: config });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/api/office-config', async (req, res) => {
  try {
    const { lat, lng, maxRadiusMeters, name } = req.body;
    if (lat === undefined || lng === undefined || maxRadiusMeters === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Cần truyền đầy đủ: lat, lng, maxRadiusMeters'
      });
    }

    const updated = await geoService.updateOfficeConfig({
      lat: Number(lat),
      lng: Number(lng),
      maxRadiusMeters: Number(maxRadiusMeters),
      ...(name ? { name: String(name) } : {})
    });

    // Phát sự kiện realtime tới Web Admin & Mobile App qua Socket.IO
    io.emit('office:config_updated', updated);

    console.log(
      `[OfficeConfig] Đã cập nhật tọa độ công ty: (${updated.lat}, ${updated.lng}) - Bán kính: ${updated.maxRadiusMeters}m`
    );

    return res.json({
      success: true,
      message: 'Cập nhật vị trí và bán kính chấm công thành công!',
      data: updated
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'UP',
    mongoConnected: isMongoConnected(),
    port: PORT,
    timestamp: new Date().toISOString()
  });
});

// ==========================================
// START SERVER
// ==========================================
const PORT = Number(process.env.PORT) || 3000;

async function start() {
  // Lắng nghe trên 0.0.0.0 để cả máy ảo Android (10.0.2.2) và điện thoại thật qua Wi-Fi đều kết nối được
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`=======================================================`);
    console.log(`[SERVER TS] Backend Điểm Danh & Tracking ĐANG CHẠY!`);
    console.log(`[DASHBOARD] Mở trình duyệt xem Dashboard: http://localhost:${PORT}`);
    console.log(`[NETWORK]   http://0.0.0.0:${PORT}`);
    console.log(`[EMULATOR]  http://10.0.2.2:${PORT}`);
    console.log(`=======================================================`);
  });

  // Khởi động kết nối MongoDB Atlas song song (không làm chậm hay treo server nếu mạng yếu)
  connectMongo().catch((err) => {
    console.error('[MONGODB] Cảnh báo kết nối Atlas:', err.message);
  });
}

start();
