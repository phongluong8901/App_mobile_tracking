import { attendanceService } from '../services/attendance.service';

export const attendancePromptsDefinitions = [
  {
    name: 'summarize_attendance',
    description: 'Tạo báo cáo tổng kết tình hình điểm danh, tỷ lệ thành công và các vi phạm.',
    arguments: [
      {
        name: 'date',
        description: 'Ngày cần tổng kết (định dạng YYYY-MM-DD)',
        required: false
      }
    ]
  }
];

export async function handleGetPrompt(name: string, args?: Record<string, string>) {
  if (name !== 'summarize_attendance') {
    throw new Error(`Prompt không tồn tại: ${name}`);
  }

  const date = args?.date;
  const logs = await attendanceService.getLogs();
  const filtered = date ? logs.filter((l) => l.timestamp.startsWith(date)) : logs;

  return {
    messages: [
      {
        role: 'user',
        content: {
          type: 'text',
          text: `Dưới đây là danh sách điểm danh ${
            date ? `trong ngày ${date}` : 'gần đây'
          }:\n${JSON.stringify(filtered, null, 2)}\n\nHãy phân tích và lập báo cáo:
1. Tổng số lượt điểm danh thành công / thất bại.
2. Danh sách các trường hợp thất bại (do Fake GPS, sai mặt, hoặc ngoài khoảng cách).
3. Đánh giá tính tuân thủ và cảnh báo các hành vi bất thường.`
        }
      }
    ]
  };
}
