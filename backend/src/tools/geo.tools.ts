import { z } from 'zod';
import { geoService } from '../services/geo.service';
import { trackingService } from '../services/tracking.service';

export const CheckGeofenceSchema = z.object({
  lat: z.number().describe('Vĩ độ cần kiểm tra'),
  lng: z.number().describe('Kinh độ cần kiểm tra')
});

export const UpdateOfficeLocationSchema = z.object({
  lat: z.number().optional().describe('Vĩ độ văn phòng mới'),
  lng: z.number().optional().describe('Kinh độ văn phòng mới'),
  maxRadiusMeters: z
    .number()
    .positive()
    .optional()
    .describe('Bán kính cho phép điểm danh mới (mét)')
});

export const TrackLiveLocationSchema = z.object({
  userId: z.string().describe('Mã nhân viên'),
  lat: z.number().describe('Vĩ độ hiện tại'),
  lng: z.number().describe('Kinh độ hiện tại'),
  speed: z.number().optional().describe('Tốc độ di chuyển (m/s)'),
  timestamp: z.string().optional().describe('Thời gian (ISO string)')
});

export const geoToolsDefinitions = [
  {
    name: 'check_geofence',
    description:
      'Kiểm tra tọa độ GPS có nằm trong bán kính cho phép của văn phòng hay không và tính khoảng cách.',
    inputSchema: {
      type: 'object',
      properties: {
        lat: { type: 'number', description: 'Vĩ độ cần kiểm tra' },
        lng: { type: 'number', description: 'Kinh độ cần kiểm tra' }
      },
      required: ['lat', 'lng']
    }
  },
  {
    name: 'update_office_location',
    description: 'Cập nhật tọa độ GPS và bán kính điểm danh của văn phòng.',
    inputSchema: {
      type: 'object',
      properties: {
        lat: { type: 'number', description: 'Vĩ độ mới' },
        lng: { type: 'number', description: 'Kinh độ mới' },
        maxRadiusMeters: { type: 'number', description: 'Bán kính mới (mét)' }
      }
    }
  },
  {
    name: 'track_live_location',
    description: 'Cập nhật vị trí GPS thời gian thực và tốc độ di chuyển của nhân viên.',
    inputSchema: {
      type: 'object',
      properties: {
        userId: { type: 'string', description: 'Mã nhân viên' },
        lat: { type: 'number', description: 'Vĩ độ hiện tại' },
        lng: { type: 'number', description: 'Kinh độ hiện tại' },
        speed: { type: 'number', description: 'Tốc độ di chuyển (m/s)' },
        timestamp: { type: 'string', description: 'Thời gian ISO string' }
      },
      required: ['userId', 'lat', 'lng']
    }
  }
];

export async function handleCheckGeofence(args: unknown) {
  const { lat, lng } = CheckGeofenceSchema.parse(args);
  const result = await geoService.checkGeofence(lat, lng);

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            isWithinGeofence: result.isInside,
            distanceMeters: result.distanceMeters,
            maxAllowedRadiusMeters: result.office.maxRadiusMeters,
            officeLocation: {
              lat: result.office.lat,
              lng: result.office.lng
            },
            userLocation: { lat, lng }
          },
          null,
          2
        )
      }
    ]
  };
}

export async function handleUpdateOfficeLocation(args: unknown) {
  const params = UpdateOfficeLocationSchema.parse(args);
  const updatedConfig = await geoService.updateOfficeConfig(params);

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            success: true,
            message: 'Cập nhật cấu hình văn phòng thành công',
            config: updatedConfig
          },
          null,
          2
        )
      }
    ]
  };
}

export async function handleTrackLiveLocation(args: unknown) {
  const { userId, lat, lng, speed, timestamp } = TrackLiveLocationSchema.parse(args);
  const record = {
    userId,
    lat,
    lng,
    speed: speed ?? 0,
    timestamp: timestamp || new Date().toISOString()
  };

  const result = await trackingService.updateLocation(record);

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            success: true,
            message: `Đã cập nhật vị trí live cho ${userId}`,
            data: {
              ...result.record,
              distanceToOfficeMeters: result.distanceToOfficeMeters,
              isInsideOfficeGeofence: result.isInsideOfficeGeofence
            }
          },
          null,
          2
        )
      }
    ]
  };
}
