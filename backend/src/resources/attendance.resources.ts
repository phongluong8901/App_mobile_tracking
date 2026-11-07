import { attendanceService } from '../services/attendance.service';
import { faceService } from '../services/face.service';
import { geoService } from '../services/geo.service';
import { trackingService } from '../services/tracking.service';

export const attendanceResourcesDefinitions = [
  {
    uri: 'attendance://logs',
    name: 'Attendance Logs',
    description: 'Toàn bộ nhật ký điểm danh của hệ thống',
    mimeType: 'application/json'
  },
  {
    uri: 'attendance://users',
    name: 'Registered Users',
    description: 'Danh sách nhân viên đã đăng ký khuôn mặt',
    mimeType: 'application/json'
  },
  {
    uri: 'attendance://config',
    name: 'Office Configuration',
    description: 'Cấu hình tọa độ văn phòng và bán kính Geofencing hiện tại',
    mimeType: 'application/json'
  },
  {
    uri: 'attendance://live-locations',
    name: 'Live Locations',
    description: 'Danh sách vị trí GPS thời gian thực của các nhân viên',
    mimeType: 'application/json'
  }
];

export async function handleReadResource(uri: string) {
  switch (uri) {
    case 'attendance://logs': {
      const logs = await attendanceService.getLogs();
      return {
        contents: [
          {
            uri,
            text: JSON.stringify(logs, null, 2),
            mimeType: 'application/json'
          }
        ]
      };
    }
    case 'attendance://users': {
      const users = await faceService.getAllUsers();
      return {
        contents: [
          {
            uri,
            text: JSON.stringify(users, null, 2),
            mimeType: 'application/json'
          }
        ]
      };
    }
    case 'attendance://config': {
      const config = await geoService.getOfficeConfig();
      return {
        contents: [
          {
            uri,
            text: JSON.stringify(config, null, 2),
            mimeType: 'application/json'
          }
        ]
      };
    }
    case 'attendance://live-locations': {
      const locations = await trackingService.getAllLiveLocations();
      return {
        contents: [
          {
            uri,
            text: JSON.stringify(locations, null, 2),
            mimeType: 'application/json'
          }
        ]
      };
    }
    default:
      throw new Error(`Resource không hợp lệ hoặc không tìm thấy: ${uri}`);
  }
}
