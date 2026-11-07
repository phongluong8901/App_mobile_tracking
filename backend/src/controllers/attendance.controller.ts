import { Request, Response } from 'express';
import { attendanceService } from '../services/attendance.service';
import { Server as SocketIOServer } from 'socket.io';

export class AttendanceController {
  private io?: SocketIOServer;

  setSocketIO(io: SocketIOServer) {
    this.io = io;
  }

  async checkIn(req: Request, res: Response): Promise<Response> {
    try {
      const { userId, type, lat, lng, isMocked, embedding, deviceId } = req.body;

      if (!userId || lat === undefined || lng === undefined || !Array.isArray(embedding)) {
        return res.status(200).json({
          success: false,
          message: 'Dữ liệu không hợp lệ: Thiếu userId, tọa độ GPS hoặc vector khuôn mặt',
          data: {
            status: 'REJECTED',
            rejectionReason: 'Thiếu thông tin bắt buộc trong request'
          }
        });
      }

      const result = await attendanceService.processCheckIn({
        userId,
        type,
        lat: Number(lat),
        lng: Number(lng),
        isMocked: Boolean(isMocked),
        embedding,
        deviceId
      });

      // Phát sự kiện realtime cho Admin Dashboard nếu điểm danh thành công
      if (this.io && result.data && result.success) {
        this.io.emit('admin:new-checkin', result.data);
      }

      // Trả về HTTP 200 kèm success: true/false và data record đầy đủ cho Flutter App
      return res.status(200).json(result);
    } catch (error: any) {
      console.error('[AttendanceController.checkIn ERROR]', error);
      return res.status(200).json({
        success: false,
        message: error.message || 'Lỗi xử lý điểm danh nội bộ',
        data: {
          status: 'REJECTED',
          rejectionReason: error.message || 'Lỗi hệ thống'
        }
      });
    }
  }

  async getLogs(req: Request, res: Response): Promise<Response> {
    try {
      const userId = req.query.userId as string | undefined;
      const limit = req.query.limit ? parseInt(req.query.limit as string) : undefined;

      const logs = await attendanceService.getLogs({ userId, limit });
      return res.status(200).json({
        success: true,
        total: logs.length,
        data: logs
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }
}

export const attendanceController = new AttendanceController();
