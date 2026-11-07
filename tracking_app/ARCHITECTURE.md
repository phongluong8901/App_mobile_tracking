# Kiến Trúc Ứng Dụng Flutter (Clean Architecture: Controller - Service - Repository)

Tài liệu chi tiết về cấu trúc phân tầng (Layered Architecture) của ứng dụng **Flutter Tracking App**.

---

## 🏗️ Sơ đồ tổng quan phân tầng

```
┌─────────────────────────────────────────────────────────────┐
│                        VIEW LAYER                           │
│  - AttendanceScreen                                         │
│  - CameraPreviewWidget, ActionButtonsWidget                 │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Lắng nghe State / Gọi Action)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     CONTROLLER LAYER                        │
│  - AttendanceController (ChangeNotifier)                    │
│    * Quản lý trạng thái camera, chớp mắt, liveness, GPS     │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│      REPOSITORY LAYER        │ │       SERVICE LAYER        │
│  - AttendanceRepository      │ │  - CameraService           │
│  - UserRepository            │ │  - FaceDetectorService     │
└──────────────┬───────────────┘ │  - FaceAIService (TFLite)  │
               │                 │  - LocationService (GPS)   │
               ▼                 │  - SocketService (WS)      │
┌──────────────────────────────┐ │  - AttendanceApiService    │
│      NETWORK / API LAYER     │ └────────────────────────────┘
│  - AttendanceApiService      │
│    (HTTP REST Client)        │
└──────────────┬───────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│                 BACKEND SERVER (Node.js/TS)                 │
│      http://10.0.2.2:3000 hoặc http://192.168.1.x:3000      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Chi tiết các tầng trong thư mục `lib/`

### 1. `lib/models/` (Data Entities)
Chứa các đối tượng dữ liệu thuần túy (POJO / DTO) có chuyển đổi JSON:
- [`attendance_model.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/models/attendance_model.dart): Đại diện cho bản ghi điểm danh (id, userId, khoảng cách, độ tương đồng, trạng thái SUCCESS/REJECTED, lý do).
- [`user_model.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/models/user_model.dart): Thông tin nhân viên và vector khuôn mặt 192 chiều.
- [`location_data.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/models/location_data.dart): Tọa độ vĩ độ/kinh độ, tốc độ và cờ `isMocked` (phát hiện Fake GPS).

### 2. `lib/services/` (Hardware & Third-Party SDK Wrappers)
Các dịch vụ độc lập chịu trách nhiệm giao tiếp trực tiếp với phần cứng hoặc thư viện ngoài:
- [`camera_service.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/services/camera_service.dart): Khởi tạo Camera trước, quản lý vòng đời camera và stream khung hình (`startImageStream`, `stopImageStream`).
- [`face_detector_service.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/services/face_detector_service.dart): Sử dụng **Google ML Kit Face Detection** để phát hiện mặt, đo xác suất mở mắt (`leftEyeOpenProbability`, `rightEyeOpenProbability`) và nhận diện chu trình chớp mắt (Liveness Detection).
- [`face_ai_service.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/services/face_ai_service.dart): Nạp model TFLite `mobilefacenet.tflite` và trích xuất vector đặc trưng 192 chiều từ khung hình camera.
- [`location_service.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/services/location_service.dart): Xin quyền GPS, lấy vị trí chính xác cao từ `geolocator` và lắng nghe sự thay đổi vị trí theo quãng đường (distanceFilter).
- [`socket_service.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/services/socket_service.dart): Kết nối WebSocket Socket.IO tới server và phát sự kiện `location:update` liên tục khi bật Live Tracking.
- [`attendance_api_service.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/services/attendance_api_service.dart): HTTP Client thực hiện gọi API `/api/register-face` và `/api/check-in`.

### 3. `lib/repositories/` (Data Access Abstraction)
Cung cấp một lớp trừu tượng trung gian giữa Data Source (API/Local) và Controller:
- [`attendance_repository.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/repositories/attendance_repository.dart): Gọi `AttendanceApiService`, chuyển đổi response thô thành `AttendanceRecordModel`, bảo vệ controller khỏi các chi tiết giao thức HTTP.
- [`user_repository.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/repositories/user_repository.dart): Cung cấp thông tin nhân viên và định danh thiết bị từ cấu hình.

### 4. `lib/controllers/` (State Management & Business Coordination)
- [`attendance_controller.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/controllers/attendance_controller.dart):
  - Kế thừa `ChangeNotifier` để thông báo cập nhật UI một cách phản ứng (reactive).
  - Điều phối chu trình: Camera stream -> ML Kit đo chớp mắt -> TFLite trích xuất 192 chiều -> Định vị GPS chống Fake -> Gọi Repository điểm danh -> Bật/Tắt Socket Live Tracking.
  - Tách hoàn toàn logic nghiệp vụ ra khỏi giao diện màn hình.

### 5. `lib/views/` (Presentation Layer)
- [`attendance_screen.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/views/attendance_screen.dart): Màn hình chính chứa thanh điều hướng `BottomNavigationBar` với 2 tab riêng biệt.
- [`tabs/attendance_tab.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/views/tabs/attendance_tab.dart): **Tab Chấm Công** - Camera preview, liveness detection chớp mắt, nút "Đăng Ký Mặt Gốc", nút "Chấm Công / Điểm Danh", hiển thị kết quả điểm danh chi tiết.
- [`tabs/location_tab.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/views/tabs/location_tab.dart): **Tab Lấy Vị Trí (GPS)** - Lấy tọa độ GPS tức thời (kinh độ, vĩ độ, tốc độ), kiểm tra Fake GPS (`isMocked`), trạng thái kết nối WebSocket Socket.IO, nút bật/tắt Live Tracking và bảng lịch sử lộ trình.
- [`widgets/camera_preview_widget.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/views/widgets/camera_preview_widget.dart): Widget hiển thị camera và hiệu ứng khung oval chuyển xanh khi xác thực thành công.

### 6. `lib/config/`
- [`app_config.dart`](file:///d:/A_HackerBasic/All_projects/Flutter/proj_4/tracking_app/lib/config/app_config.dart): Nạp các biến môi trường từ file `.env` (`SERVER_URL`, `SOCKET_URL`, `CURRENT_USER_ID`, `USER_NAME`, `DEVICE_ID`).

---

## 🔄 Chu trình hoạt động chi tiết (Flow)

### A. Quy trình Đăng ký khuôn mặt gốc (1 lần ban đầu):
1. Nhân viên mở **Tab Chấm Công**.
2. Nhìn vào camera và **chớp mắt** để hệ thống xác nhận người thật (Liveness Detection).
3. Sau khi vòng oval chuyển sang **xanh lá**, bấm nút **"Đăng Ký Khuôn Mặt Gốc Lần Đầu"**.
4. App trích xuất vector 192 chiều đặc trưng và gửi lên Backend qua `POST /api/register-face`.
5. Backend lưu vector này vào Database (MongoDB) làm mẫu đối chiếu chuẩn cho nhân viên đó.

### B. Quy trình Chấm công / Điểm danh hàng ngày:
1. Mỗi ngày khi đến công ty, nhân viên mở **Tab Chấm Công**.
2. Nhìn vào camera và **chớp mắt** ➔ Hệ thống trích xuất vector 192 chiều của khuôn mặt hiện tại.
3. Bấm nút **"CHẤM CÔNG (ĐIỂM DANH)"**.
4. App tự động lấy tọa độ GPS của thiết bị và kiểm tra cờ chống Fake GPS (`isMocked`).
5. Gửi toàn bộ dữ liệu (tọa độ GPS + cờ `isMocked` + vector 192 chiều) lên Backend qua `POST /api/check-in`.
6. **Backend xử lý**:
   - Kiểm tra khoảng cách GPS: nếu cách công ty < 200m ➔ Hợp lệ.
   - Kiểm tra chống Fake GPS: nếu `isMocked == true` ➔ Từ chối ngay.
   - So khớp vector: Tính khoảng cách Euclidean giữa vector hiện tại và vector mẫu đã đăng ký ở Bước A. Nếu độ tương đồng > 0.8 ➔ Hợp lệ.
   - Trả về kết quả: `SUCCESS` hoặc `REJECTED` kèm lý do cụ thể hiển thị ngay trên màn hình.

### C. Quy trình Giám sát vị trí Live Tracking (Tab Vị Trí):
1. Chuyển sang **Tab Lấy Vị Trí (GPS)**.
2. Có thể bấm **"Lấy Vị Trí"** để xem ngay tọa độ Lat, Lng, tốc độ và trạng thái GPS thật/giả.
3. Bấm **"Bật Live Tracking"** ➔ App tự động gửi tọa độ lên Backend qua sự kiện Socket.IO `location:update` mỗi khi di chuyển được 10 mét.

