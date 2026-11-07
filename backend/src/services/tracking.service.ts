import { locationRepository } from '../repositories/location.repository';
import { geoService } from './geo.service';
import { LiveLocationRecord } from '../types';

export class TrackingService {
  async updateLocation(record: LiveLocationRecord): Promise<{
    record: LiveLocationRecord;
    distanceToOfficeMeters: number;
    isInsideOfficeGeofence: boolean;
  }> {
    await locationRepository.upsertLocation(record);

    const office = await geoService.getOfficeConfig();
    const distance = geoService.calculateDistance(
      record.lat,
      record.lng,
      office.lat,
      office.lng
    );

    return {
      record,
      distanceToOfficeMeters: Math.round(distance),
      isInsideOfficeGeofence: distance <= office.maxRadiusMeters
    };
  }

  async getAllLiveLocations(): Promise<LiveLocationRecord[]> {
    return await locationRepository.findAll();
  }

  async getUserLocation(userId: string): Promise<LiveLocationRecord | null> {
    return await locationRepository.findByUserId(userId);
  }
}

export const trackingService = new TrackingService();

