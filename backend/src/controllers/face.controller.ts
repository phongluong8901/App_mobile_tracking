import { Request, Response } from 'express';
import { faceService } from '../services/face.service';

export class FaceController {
  async registerFace(req: Request, res: Response): Promise<Response> {
    try {
      const { userId, name, embedding } = req.body;

      console.log(
        `[FaceController] Nhận yêu cầu đăng ký mặt: userId="${userId}", name="${name}", vector length=${
          Array.isArray(embedding) ? embedding.length : 'NOT_ARRAY'
        }`
      );

      if (!userId || !Array.isArray(embedding) || embedding.length !== 192) {
        return res.status(200).json({
          success: false,
          message: `Dữ liệu không hợp lệ: Cần userId và mảng vector embedding đúng 192 chiều! (Hiện tại: ${
            Array.isArray(embedding) ? embedding.length : 'không phải mảng'
          })`
        });
      }

      const user = await faceService.registerFace(userId, name, embedding);
      console.log(`[FaceController] ✅ ĐÃ LƯU THÀNH CÔNG vector khuôn mặt gốc cho: ${userId} (${user.name})`);

      return res.status(200).json({
        success: true,
        message: `Đã lưu khuôn mặt gốc cho nhân viên ${user.name} (${userId}) thành công!`,
        data: {
          userId: user.userId,
          name: user.name,
          registeredAt: user.registeredAt
        }
      });
    } catch (error: any) {
      console.error('[FaceController.registerFace ERROR]', error);
      return res.status(200).json({
        success: false,
        message: error.message || 'Lỗi xử lý đăng ký khuôn mặt'
      });
    }
  }

  async verifyFace(req: Request, res: Response): Promise<Response> {
    try {
      const { userId, embedding } = req.body;
      const result = await faceService.verifyFace(userId, embedding);

      if (!result.user) {
        return res.status(200).json({
          success: false,
          message: `Không tìm thấy user ${userId}`
        });
      }

      return res.status(200).json({
        success: result.matched,
        userId,
        similarity: result.similarity,
        threshold: result.threshold,
        status: result.matched ? 'MATCHED' : 'NOT_MATCHED'
      });
    } catch (error: any) {
      return res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  async getAllUsers(req: Request, res: Response): Promise<Response> {
    try {
      const users = await faceService.getAllUsers();
      return res.status(200).json({ success: true, data: users });
    } catch (error: any) {
      return res.status(500).json({ success: false, message: error.message });
    }
  }
}

export const faceController = new FaceController();
