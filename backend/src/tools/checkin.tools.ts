import { z } from 'zod';
import { attendanceService } from '../services/attendance.service';
import { MOBILE_FACENET_EMBEDDING_DIM } from '../config';

export const CheckInSchema = z.object({
  userId: z.string().describe('Mã định danh nhân viên'),
  lat: z.number().describe('Vĩ độ hiện tại của thiết bị'),
  lng: z.number().describe('Kinh độ hiện tại của thiết bị'),
  isMocked: z.boolean().describe('Cờ phát hiện Fake GPS / Vị trí giả mạo từ App điện thoại'),
  embedding: z
    .array(z.number())
    .length(MOBILE_FACENET_EMBEDDING_DIM)
    .describe(`Vector khuôn mặt 192 chiều từ camera tại thời điểm điểm danh`),
  deviceId: z.string().optional().describe('ID thiết bị di động (tùy chọn)')
});

export const GetAttendanceLogsSchema = z.object({
  userId: z.string().optional().describe('Mã nhân viên cần lọc (để trống nếu muốn lấy tất cả)'),
  limit: z.number().optional().describe('Số lượng bản ghi tối đa cần lấy (mặc định lấy tất cả)')
});

export const checkInToolsDefinitions = [
  {
    name: 'check_in',
    description:
      'Thực hiện điểm danh nhân viên: Xác thực GPS, phát hiện Fake GPS, kiểm tra khoảng cách văn phòng và đối chiếu khuôn mặt.',
    inputSchema: {
      type: 'object',
      properties: {
        userId: { type: 'string', description: 'Mã định danh nhân viên' },
        lat: { type: 'number', description: 'Vĩ độ hiện tại' },
        lng: { type: 'number', description: 'Kinh độ hiện tại' },
        isMocked: { type: 'boolean', description: 'Có dùng Fake GPS không' },
        embedding: {
          type: 'array',
          items: { type: 'number' },
          description: 'Vector khuôn mặt 192 phần tử'
        },
        deviceId: { type: 'string', description: 'ID thiết bị di động' }
      },
      required: ['userId', 'lat', 'lng', 'isMocked', 'embedding']
    }
  },
  {
    name: 'get_attendance_logs',
    description:
      'Lấy danh sách lịch sử điểm danh (có thể lọc theo userId hoặc giới hạn số lượng record).',
    inputSchema: {
      type: 'object',
      properties: {
        userId: { type: 'string', description: 'Mã nhân viên cần lọc' },
        limit: { type: 'number', description: 'Số bản ghi tối đa' }
      }
    }
  }
];

export async function handleCheckIn(args: unknown) {
  const parsed = CheckInSchema.parse(args);
  const result = await attendanceService.processCheckIn(parsed);

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(result, null, 2)
      }
    ]
  };
}

export async function handleGetAttendanceLogs(args: unknown) {
  const { userId, limit } = GetAttendanceLogsSchema.parse(args || {});
  const logs = await attendanceService.getLogs({ userId, limit });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            total: logs.length,
            logs
          },
          null,
          2
        )
      }
    ]
  };
}
