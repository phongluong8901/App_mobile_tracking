# Kiến Trúc Backend TypeScript (Controller - Service - Repository & MCP)

Tài liệu chi tiết về kiến trúc phân tầng của Backend **Điểm danh & Tracking nhận diện khuôn mặt** (Đã đồng bộ 100% với Frontend Flutter theo [`BACKEND_INTEGRATION_SPEC.md`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/BACKEND_INTEGRATION_SPEC.md)).

---

## 🏗️ Sơ đồ tổng quan phân tầng Backend

```
          ┌───────────────────────────┐         ┌───────────────────────────┐
          │     FLUTTER CLIENT        │         │      AI AGENT CLIENT      │
          │    (Mobile / Browser)     │         │ (Claude / Cursor / IDE)   │
          └─────────────┬─────────────┘         └─────────────┬─────────────┘
                        │ HTTP / WebSocket                    │ MCP Protocol (Stdio)
                        ▼                                     ▼
          ┌───────────────────────────┐         ┌───────────────────────────┐
          │     CONTROLLER LAYER      │         │     MCP HANDLER LAYER     │
          │ - FaceController          │         │ - face.tools.ts           │
          │ - AttendanceController    │         │ - checkin.tools.ts        │
          │ - TrackingController      │         │ - geo.tools.ts            │
          └─────────────┬─────────────┘         └─────────────┬─────────────┘
                        │                                     │
                        └──────────────────┬──────────────────┘
                                           │
                                           ▼
          ┌─────────────────────────────────────────────────────────┐
          │                      SERVICE LAYER                      │
          │  - FaceService (Vector validation, Cosine Similarity)   │
          │  - GeoService (Haversine formula, Geofence 200m)       │
          │  - AttendanceService (Business pipeline rules)          │
          │  - TrackingService (Realtime location update)           │
          └────────────────────────────┬────────────────────────────┘
                                       │
                                       ▼
          ┌─────────────────────────────────────────────────────────┐
          │                    REPOSITORY LAYER                     │
          │  - UserRepository (UserModel CRUD)                      │
          │  - AttendanceRepository (AttendanceModel CRUD)          │
          │  - LocationRepository (LiveLocationModel CRUD)          │
          │  - OfficeRepository (OfficeConfigModel CRUD)            │
          └────────────────────────────┬────────────────────────────┘
                                       │
                                       ▼
          ┌─────────────────────────────────────────────────────────┐
          │                  DATABASE & CLOUD LAYER                 │
          │           MongoDB Atlas (Mongoose ODM)                  │
          │  - users, attendances, livelocations, officeconfigs     │
          └─────────────────────────────────────────────────────────┘
```

---

## 🎯 Thông số quy chuẩn đồng bộ với Frontend (`BACKEND_INTEGRATION_SPEC`)

| Tham số | Giá trị quy chuẩn | Ý nghĩa |
| :--- | :--- | :--- |
| `COMPANY_LAT` / `OFFICE_LAT` | `21.028511` | Vĩ độ trụ sở công ty tại Hà Nội |
| `COMPANY_LNG` / `OFFICE_LNG` | `105.854444` | Kinh độ trụ sở công ty tại Hà Nội |
| `MAX_ALLOWED_DISTANCE_METERS` | `200` mét | Bán kính cho phép điểm danh hợp lệ |
| `MIN_FACE_SIMILARITY` | `0.80` (80%) | Ngưỡng Cosine Similarity tối thiểu để công nhận khuôn mặt |
| `MOBILE_FACENET_EMBEDDING_DIM`| `192` | Kích thước vector MobileFaceNet (kết quả eKYC đa góc) |

---

## 📁 Chi tiết các tầng trong Backend

### 1. `src/repositories/` (Data Access Layer)
Chịu trách nhiệm trực tiếp truy vấn, lưu trữ và cập nhật dữ liệu với **MongoDB Atlas**:
- [`user.repository.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/repositories/user.repository.ts): Quản lý tài khoản và vector khuôn mặt gốc 192 chiều (kết quả tổng hợp eKYC 5 góc từ Flutter).
- [`attendance.repository.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/repositories/attendance.repository.ts): Lưu trữ toàn bộ nhật ký điểm danh (`SUCCESS` hoặc `REJECTED`).
- [`location.repository.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/repositories/location.repository.ts): Cập nhật vị trí GPS realtime của từng nhân viên.
- [`office.repository.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/repositories/office.repository.ts): Quản lý cấu hình tọa độ văn phòng và bán kính Geofence.

### 2. `src/services/` (Business Logic Layer)
Xử lý toàn bộ logic nghiệp vụ, toán học và kiểm tra bảo mật:
- [`face.service.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/services/face.service.ts): Xác thực kích thước vector 192 chiều, tính độ tương đồng **Cosine Similarity**, so sánh với ngưỡng $\ge 80\%$.
- [`geo.service.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/services/geo.service.ts): Tính khoảng cách mét giữa 2 tọa độ GPS bằng công thức **Haversine**, kiểm tra vi phạm bán kính 200m.
- [`attendance.service.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/services/attendance.service.ts): Pipeline điểm danh 5 bước:
  1. Chặn Fake GPS (`isMocked === true`) ➔ REJECTED.
  2. Kiểm tra tài khoản đã đăng ký vector eKYC trong DB chưa ➔ REJECTED nếu chưa có.
  3. Đo khoảng cách GPS bằng Haversine ➔ REJECTED nếu $> 200$m.
  4. Đối chiếu vector khuôn mặt bằng Cosine Similarity ➔ REJECTED nếu $< 0.80$.
  5. Chấp thuận điểm danh ➔ SUCCESS & lưu vào MongoDB Atlas.
- [`tracking.service.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/services/tracking.service.ts): Xử lý cập nhật vị trí di chuyển và tính khoảng cách tới cơ quan thời gian thực.

### 3. `src/controllers/` (Presentation & Transport Layer cho Flutter Mobile)
Nhận HTTP Request từ Flutter App, xác thực tham số đầu vào và trả về JSON:
- [`face.controller.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/controllers/face.controller.ts):
  - `POST /api/register-face`: Tiếp nhận vector 192 chiều (tổng hợp 5 góc eKYC) và lưu vào MongoDB.
- [`attendance.controller.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/controllers/attendance.controller.ts):
  - `POST /api/check-in`: Xử lý điểm danh, trả về JSON đồng nhất cho Flutter, đồng thời emit `admin:new-checkin`.
  - `GET /api/attendance-logs`: Truy vấn lịch sử điểm danh.
- [`tracking.controller.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/controllers/tracking.controller.ts):
  - Socket.IO `location:update`: Nhận tọa độ GPS mỗi 10m từ Flutter, lưu vào MongoDB và broadcast qua sự kiện `admin:location_stream` (và `admin:live-location`).

### 4. `src/tools/` (Model Context Protocol Layer cho AI Agent)
Đóng gói các Services thành chuẩn **MCP Tools** cho AI Agent:
- [`face.tools.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/tools/face.tools.ts): Tool `register_face`, `verify_face`.
- [`checkin.tools.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/tools/checkin.tools.ts): Tool `check_in`, `get_attendance_logs`.
- [`geo.tools.ts`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/backend/src/tools/geo.tools.ts): Tool `check_geofence`, `update_office_location`, `track_live_location`.

---

## 🚀 Cách chạy Backend theo 2 chế độ

```powershell
# Chế độ 1: Dành cho Flutter Mobile App (Khởi chạy HTTP REST API + Socket.IO cổng 3000)
npm run dev:api

# Chế độ 2: Dành cho AI Agent (Khởi chạy Model Context Protocol Server qua Stdio)
npm run dev:mcp
```
