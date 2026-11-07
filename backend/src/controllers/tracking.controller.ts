import { Socket, Server as SocketIOServer } from 'socket.io';
import { trackingService } from '../services/tracking.service';

export class TrackingController {
  setupSocket(io: SocketIOServer) {
    io.on('connection', (socket: Socket) => {
      console.log(`[Socket.IO] Thiết bị kết nối thành công: ${socket.id}`);

      // Lắng nghe tọa độ liên tục từ Flutter app
      socket.on('location:update', async (payload: any) => {
        try {
          const { userId, lat, lng, speed, timestamp } = payload;
          if (!userId || lat === undefined || lng === undefined) return;

          const record = {
            userId,
            lat: Number(lat),
            lng: Number(lng),
            speed: Number(speed) || 0,
            timestamp: timestamp || new Date().toISOString()
          };

          // Cập nhật và lưu vị trí vào MongoDB Atlas
          const result = await trackingService.updateLocation(record);

          console.log(
            `[Live Tracking] User ${userId} -> (${lat}, ${lng}) | Cách cty: ${result.distanceToOfficeMeters}m | Vận tốc: ${speed}m/s`
          );

          const broadcastData = {
            ...result.record,
            distanceToOfficeMeters: result.distanceToOfficeMeters,
            isInsideOfficeGeofence: result.isInsideOfficeGeofence
          };

          // Broadcast cho Dashboard Admin theo chuẩn spec:
          socket.broadcast.emit('admin:location_stream', broadcastData);
          // Đồng thời emit admin:live-location để tương thích ngược
          socket.broadcast.emit('admin:live-location', broadcastData);
        } catch (error) {
          console.error('[TrackingController ERROR]', error);
        }
      });

      socket.on('disconnect', () => {
        console.log(`[Socket.IO] Thiết bị ngắt kết nối: ${socket.id}`);
      });
    });
  }
}

export const trackingController = new TrackingController();
