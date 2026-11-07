# 📘 TÀI LIỆU ĐẶC TẢ KẾT NỐI BACKEND (BACKEND INTEGRATION SPEC)

Tài liệu hướng dẫn chi tiết dành cho lập trình viên Backend (Node.js / Express / TypeScript / Python) để xây dựng hệ thống Server kết nối đồng bộ 100% với ứng dụng **Flutter Tracking App**.

---

## 🎯 1. Cơ Chế Đăng Ký Khuôn Mặt eKYC Đa Góc & Điểm Danh (Face Recognition & Attendance)

### 1.1. Quy trình Đăng ký mặt gốc 5 Góc chuẩn eKYC Ngân hàng (1 lần đầu):
Khi nhân viên bấm **"Đăng Ký Khuôn Mặt (Quét 5 Góc eKYC)"**, ứng dụng kích hoạt vòng tròn 60 vạch chia độ (giống FaceID / eKYC ngân hàng) và hướng dẫn nhân viên quay mặt qua **5 góc**:
1. **Bước 1 (20%) - Nhìn thẳng (`lookStraight`)**: Đo góc `|yaw| < 12°`, `|pitch| < 14°` ➔ Trích xuất vector $\vec{v}_1$ (192 chiều).
2. **Bước 2 (40%) - Quay mặt sang Trái (`turnLeft`)**: Đo góc `|yaw| > 16°` ➔ Trích xuất vector góc trái $\vec{v}_2$.
3. **Bước 3 (60%) - Quay mặt sang Phải (`turnRight`)**: Đo góc quay ngược chiều Bước 2 (`|yaw| > 16°`) ➔ Trích xuất vector góc phải $\vec{v}_3$.
4. **Bước 4 (80%) - Ngẩng nhẹ đầu hoặc Mỉm cười (`tiltOrSmile`)**: Đo `|pitch| > 9.5°` hoặc `smile > 0.5` ➔ Trích xuất vector $\vec{v}_4$.
5. **Bước 5 (100%) - Nhìn thẳng & Chớp mắt (`blinkConfirm`)**: Xác nhận thực thể sống và trích xuất vector $\vec{v}_5$.
- **Tổng hợp Vector trung bình chuẩn hóa (Centroid Embedding)**:
  App tính trung bình cộng của 5 vector $\vec{v}_1 \dots \vec{v}_5$ và chuẩn hóa L2 (`combineMultiAngleEmbeddings`) tạo ra **1 vector đại diện duy nhất (192 chiều)** bao phủ mọi góc mặt, sau đó tự động gửi lên `POST /api/register-face`.

### 1.2. Quy trình Điểm danh / Chấm công hàng ngày:
- **Điểm danh nhanh (1 giây)**: Nhân viên mở app, nhìn thẳng và **chớp mắt** ➔ App trích xuất **vector 192 chiều của khuôn mặt lúc đó** + lấy **tọa độ GPS** + cờ **chống Fake GPS** gửi lên `POST /api/check-in`. 
- **Backend đối chiếu**:
  1. Kiểm tra Fake GPS (`isMocked`). Nếu `true` ➔ Từ chối ngay.
  2. Đo khoảng cách GPS từ vị trí nhân viên đến tọa độ công ty (dùng công thức Haversine). Nếu xa hơn bán kính cho phép (ví dụ > 200m) ➔ Từ chối.
  3. Lấy vector gốc trong DB ra so sánh với vector hiện tại bằng công thức **Cosine Similarity** hoặc **Euclidean Distance**. Nếu độ tương đồng $\ge 80\%$ ➔ **Điểm danh thành công!**

---

## 🗄️ 2. Thiết Kế Cơ Sở Dữ Liệu (MongoDB Schema Gợi Ý)

### 2.1. Collection `users` (Thông tin nhân viên & Vector mặt gốc)
```json
{
  "_id": "672d...",
  "userId": "NV_001",
  "name": "Phong Luong",
  "faceEmbedding": [
    -0.04321, 0.08912, 0.01234, ... // Đúng 192 phần tử số thực (Float)
  ],
  "registeredAt": "2026-11-07T08:00:00.000Z"
}
```

### 2.2. Collection `attendances` (Lịch sử điểm danh)
```json
{
  "_id": "672e...",
  "userId": "NV_001",
  "name": "Phong Luong",
  "lat": 21.028511,
  "lng": 105.854444,
  "distance": 45, // mét
  "similarity": 0.942, // 94.2% khớp
  "deviceId": "FLUTTER_DEVICE_01",
  "timestamp": "2026-11-07T08:30:15.000Z",
  "status": "SUCCESS", // "SUCCESS" hoặc "REJECTED"
  "rejectionReason": null // Hoặc "Ngoài bán kính công ty", "Mặt không khớp", "Phát hiện Fake GPS"
}
```

---

## 🌐 3. Đặc Tả REST API (HTTP Endpoints)

### 3.1. API Đăng Ký Khuôn Mặt Gốc
- **Endpoint**: `POST /api/register-face`
- **Headers**: `Content-Type: application/json`

#### Request Body:
```json
{
  "userId": "NV_001",
  "name": "Phong Luong",
  "embedding": [
    -0.0321, 0.0854, -0.0122, ..., 0.0543 // Mảng 192 số thực
  ]
}
```

#### Response Thành Công (HTTP 200 / 201):
```json
{
  "success": true,
  "message": "Đăng ký khuôn mặt gốc thành công!",
  "data": {
    "userId": "NV_001",
    "name": "Phong Luong",
    "registeredAt": "2026-11-07T08:00:00.000Z"
  }
}
```

---

### 3.2. API Điểm Danh / Chấm Công
- **Endpoint**: `POST /api/check-in`
- **Headers**: `Content-Type: application/json`

#### Request Body:
```json
{
  "userId": "NV_001",
  "lat": 21.028511,
  "lng": 105.854444,
  "isMocked": false,
  "embedding": [
    -0.0319, 0.0860, -0.0118, ..., 0.0540 // Mảng 192 số thực khuôn mặt hiện tại
  ],
  "deviceId": "FLUTTER_DEVICE_01"
}
```

#### Response Khi Điểm Danh Thành Công (HTTP 200):
```json
{
  "success": true,
  "message": "Điểm danh thành công! Cách công ty 45m, độ khớp 94.2%",
  "data": {
    "id": 101,
    "userId": "NV_001",
    "name": "Phong Luong",
    "lat": 21.028511,
    "lng": 105.854444,
    "distance": 45,
    "similarity": 0.942,
    "deviceId": "FLUTTER_DEVICE_01",
    "timestamp": "2026-11-07T08:30:15.000Z",
    "status": "SUCCESS",
    "rejectionReason": null
  }
}
```

#### Response Khi Bị Từ Chối (HTTP 200 hoặc 400):
```json
{
  "success": false,
  "message": "Từ chối điểm danh: Bạn đang ở cách công ty 450m (cho phép tối đa 200m)",
  "data": {
    "id": 102,
    "userId": "NV_001",
    "distance": 450,
    "similarity": 0.935,
    "status": "REJECTED",
    "rejectionReason": "Vị trí nằm ngoài bán kính cho phép (450m > 200m)"
  }
}
```

---

## ⚡ 4. Đặc Tả WebSocket Socket.IO (Live Tracking Vị Trí)

- **URL kết nối**: `ws://<server-ip>:3000` (Transport: `['websocket']`)
- **Sự kiện Client gửi lên**: `'location:update'` (phát mỗi khi nhân viên di chuyển 10 mét khi bật Live Tracking).

#### Payload gửi lên từ Mobile:
```json
{
  "userId": "NV_001",
  "lat": 21.028550,
  "lng": 105.854490,
  "speed": 1.25, // m/s
  "timestamp": "2026-11-07T08:31:00.000Z"
}
```

#### Xử lý phía Server:
Lưu vào Redis hoặc MongoDB để vẽ lộ trình, hoặc broadcast sang Admin Dashboard qua event `admin:location_stream`.

---

## 💻 5. Code Mẫu Backend (Node.js + Express + TypeScript)

### 5.1. Công thức Toán học chuẩn Backend:

```typescript
// 1. Công thức Haversine tính khoảng cách giữa 2 tọa độ GPS (Đơn vị: mét)
export function calculateDistanceInMeters(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const R = 6371e3; // Bán kính Trái Đất theo mét
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) *
    Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

// 2. Công thức Cosine Similarity giữa 2 vector khuôn mặt 192 chiều
export function calculateCosineSimilarity(vecA: number[], vecB: number[]): number {
  let dotProduct = 0.0;
  let normA = 0.0;
  let normB = 0.0;

  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }

  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}
```

### 5.2. Router Express xử lý Check-in & Đăng ký:

```typescript
import { Router, Request, Response } from 'express';
import { calculateDistanceInMeters, calculateCosineSimilarity } from './utils';

const router = Router();

// Tọa độ trụ sở công ty cần chấm công
const COMPANY_LAT = 21.028511;
const COMPANY_LNG = 105.854444;
const MAX_ALLOWED_DISTANCE_METERS = 200; // 200 mét
const MIN_FACE_SIMILARITY = 0.80; // Khớp từ 80% trở lên

// POST /api/register-face
router.post('/register-face', async (req: Request, res: Response) => {
  const { userId, name, embedding } = req.body;

  if (!userId || !embedding || embedding.length !== 192) {
    return res.status(400).json({ success: false, message: 'Dữ liệu vector không hợp lệ (cần 192 chiều)!' });
  }

  // TODO: Lưu vào MongoDB: await UserModel.updateOne({ userId }, { name, faceEmbedding: embedding }, { upsert: true });

  return res.json({
    success: true,
    message: `Đã lưu khuôn mặt gốc cho nhân viên ${name} (${userId}) thành công!`
  });
});

// POST /api/check-in
router.post('/check-in', async (req: Request, res: Response) => {
  const { userId, lat, lng, isMocked, embedding, deviceId } = req.body;

  // 1. Kiểm tra Fake GPS
  if (isMocked === true) {
    return res.json({
      success: false,
      message: 'Từ chối điểm danh: Phát hiện bạn đang sử dụng ứng dụng Fake GPS!',
      data: { status: 'REJECTED', rejectionReason: 'Phát hiện ứng dụng giả lập GPS' }
    });
  }

  // 2. Kiểm tra khoảng cách GPS
  const distance = calculateDistanceInMeters(lat, lng, COMPANY_LAT, COMPANY_LNG);
  if (distance > MAX_ALLOWED_DISTANCE_METERS) {
    return res.json({
      success: false,
      message: `Từ chối điểm danh: Bạn đang cách công ty ${distance}m (cho phép tối đa ${MAX_ALLOWED_DISTANCE_METERS}m).`,
      data: { status: 'REJECTED', distance, rejectionReason: `Vượt quá bán kính công ty (${distance}m)` }
    });
  }

  // 3. Lấy vector gốc từ Database
  // const user = await UserModel.findOne({ userId });
  // Giả lập user mẫu:
  const savedEmbedding = embedding; // TODO: user.faceEmbedding

  // 4. So khớp khuôn mặt
  const similarity = calculateCosineSimilarity(embedding, savedEmbedding);
  if (similarity < MIN_FACE_SIMILARITY) {
    return res.json({
      success: false,
      message: `Từ chối: Khuôn mặt không khớp (độ tương đồng chỉ đạt ${(similarity * 100).toFixed(1)}%).`,
      data: { status: 'REJECTED', similarity, rejectionReason: 'Khuôn mặt không trùng khớp với dữ liệu đăng ký' }
    });
  }

  // 5. Chấp thuận điểm danh thành công
  return res.json({
    success: true,
    message: `Điểm danh thành công! Cách công ty ${distance}m, độ khớp ${(similarity * 100).toFixed(1)}%`,
    data: {
      id: Date.now(),
      userId,
      lat,
      lng,
      distance,
      similarity,
      deviceId,
      timestamp: new Date().toISOString(),
      status: 'SUCCESS'
    }
  });
});

export default router;
```

---

## 📱 6. Cấu Hình Biến Môi Trường Trên Mobile (`.env`)

Để ứng dụng Flutter kết nối chính xác tới Backend:

```env
# Nếu test trên điện thoại thật qua mạng WiFi nội bộ:
SERVER_URL=http://192.168.1.xxx:3000
SOCKET_URL=http://192.168.1.xxx:3000

# Nếu test qua cáp USB và đã chạy lệnh: adb reverse tcp:3000 tcp:3000
# SERVER_URL=http://localhost:3000
# SOCKET_URL=http://localhost:3000

CURRENT_USER_ID=NV_001
USER_NAME=Phong Luong
DEVICE_ID=SAMSUNG_Z_FOLD_4
```

