# Attendance & Face Recognition MCP Server (TypeScript + MongoDB Atlas)

Hệ thống backend điểm danh nhận diện khuôn mặt kết hợp Geofencing GPS được xây dựng theo chuẩn **MCP (Model Context Protocol)** bằng **TypeScript**, lưu trữ dữ liệu vĩnh viễn trên **MongoDB Atlas Cloud**.

---

## 📁 Cấu trúc thư mục

```text
backend/
├── .env                             # Cấu hình chuỗi kết nối MongoDB Atlas & thiết lập hệ thống
├── .env.example                     # Mẫu file .env
├── src/
│   ├── index.ts                     # Entry point MCP Server (kết nối MongoDB Atlas + Stdio Transport)
│   ├── config.ts                    # Đọc biến môi trường từ .env
│   ├── types/
│   │   └── index.ts                 # Định nghĩa kiểu dữ liệu TypeScript
│   ├── database/
│   │   ├── mongo.ts                 # Kết nối & quản lý vòng đời MongoDB Atlas (Mongoose)
│   │   ├── store.ts                 # Data Access Layer (lưu vào MongoDB Atlas, fallback in-memory)
│   │   └── models/                  # Mongoose Schemas & Models
│   │       ├── User.model.ts        # Lưu userId, tên, vector khuôn mặt 192 chiều
│   │       ├── Attendance.model.ts  # Lưu lịch sử điểm danh, tọa độ, GPS, độ tương đồng
│   │       ├── LiveLocation.model.ts# Lưu tọa độ và tốc độ di chuyển realtime
│   │       └── OfficeConfig.model.ts# Lưu tọa độ văn phòng & bán kính geofence
│   ├── utils/
│   │   ├── geo.ts                   # Công thức Haversine tính khoảng cách GPS, Geofence
│   │   └── math.ts                  # Cosine Similarity đối chiếu vector khuôn mặt
│   ├── tools/
│   │   ├── face.tools.ts            # MCP Tools: register_face, verify_face
│   │   ├── checkin.tools.ts         # MCP Tools: check_in, get_attendance_logs
│   │   └── geo.tools.ts             # MCP Tools: check_geofence, update_office_location, track_live_location
│   ├── resources/
│   │   └── attendance.resources.ts  # MCP Resources: attendance://logs, attendance://users, attendance://config
│   └── prompts/
│       └── attendance.prompts.ts    # MCP Prompts: summarize_attendance
├── package.json
├── tsconfig.json
├── server.js                        # Code Express/Socket.io cũ (giữ lại tham khảo)
└── README.md
```

---

## 🔑 Cấu hình .env (MongoDB Atlas)

File `.env` đã được thiết lập với tài khoản MongoDB Atlas:

```env
MONGODB_USERNAME="phongluong3366_db_user"
MONGODB_PASSWORD="aUhmjz2NzuVuaFL2"
MONGODB_URI="mongodb+srv://phongluong3366_db_user:aUhmjz2NzuVuaFL2@trackingflutter.vuzz1uv.mongodb.net/attendance_tracking?retryWrites=true&w=majority&appName=trackingflutter"
DB_NAME="attendance_tracking"

OFFICE_LAT=21.028511
OFFICE_LNG=105.804817
OFFICE_MAX_RADIUS_METERS=100
FACE_MATCH_THRESHOLD=0.78
```

---

## 🚀 Cài đặt & Chạy

### 1. Cài đặt các thư viện (bao gồm mongoose, dotenv, @modelcontextprotocol/sdk, zod, typescript)
```bash
npm install
```

### 2. Biên dịch TypeScript sang JavaScript
```bash
npm run build
```

### 3. Chạy MCP Server
- **Chế độ phát triển (sử dụng tsx chạy trực tiếp file .ts):**
  ```bash
  npm run dev
  ```
- **Chế độ Production (sau khi đã build):**
  ```bash
  npm start
  ```

---

## 🛠️ Danh sách MCP Tools (Lưu trữ MongoDB Atlas)

| Tool | Chức năng | Hành vi MongoDB Atlas |
| :--- | :--- | :--- |
| `register_face` | Đăng ký khuôn mặt với vector MobileFaceNet 192 chiều | Lưu hoặc cập nhật vào collection `users` |
| `check_in` | Điểm danh (Chống Fake GPS + Geofence + Đối chiếu khuôn mặt) | Ghi bản ghi vào collection `attendances` |
| `verify_face` | Đối chiếu vector khuôn mặt gửi lên với vector trong DB | Truy vấn vector từ collection `users` |
| `check_geofence` | Kiểm tra tọa độ có nằm trong bán kính văn phòng không | Tính khoảng cách Haversine theo config |
| `update_office_location` | Cập nhật tọa độ văn phòng và bán kính cho phép điểm danh | Lưu vào collection `officeconfigs` |
| `get_attendance_logs` | Lấy danh sách lịch sử điểm danh | Truy vấn từ collection `attendances` |
| `track_live_location` | Cập nhật vị trí GPS thời gian thực và tốc độ | Lưu hoặc cập nhật vào collection `livelocations` |

---

## 📦 Danh sách MCP Resources

- `attendance://logs`: Truy vấn danh sách lịch sử điểm danh từ Atlas.
- `attendance://users`: Danh sách nhân viên đã đăng ký trong Atlas.
- `attendance://config`: Cấu hình văn phòng từ Atlas.
- `attendance://live-locations`: Tọa độ tracking mới nhất của các nhân viên.

---

## 💬 MCP Prompts

- `summarize_attendance`: Tạo prompt cho AI Agent tổng kết báo cáo điểm danh theo ngày, tỷ lệ vi phạm (Fake GPS, khuôn mặt không khớp, ngoài vùng phủ sóng) và đánh giá độ tuân thủ.

# --- liink
https://cloud.mongodb.com/
https://console.firebase.google.com/