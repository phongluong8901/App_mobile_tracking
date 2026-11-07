import { officeRepository } from '../repositories/office.repository';
import { calculateDistanceMeters, isWithinGeofence } from '../utils/geo';
import { OfficeConfig } from '../types';

export class GeoService {
  async getOfficeConfig(): Promise<OfficeConfig> {
    return await officeRepository.getConfig();
  }

  async updateOfficeConfig(config: Partial<OfficeConfig>): Promise<OfficeConfig> {
    return await officeRepository.updateConfig(config);
  }

  async checkGeofence(
    lat: number,
    lng: number
  ): Promise<{
    isInside: boolean;
    distanceMeters: number;
    office: OfficeConfig;
  }> {
    const office = await this.getOfficeConfig();
    const result = isWithinGeofence(lat, lng, office);
    return {
      isInside: result.isInside,
      distanceMeters: result.distanceMeters,
      office
    };
  }

  calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    return calculateDistanceMeters(lat1, lon1, lat2, lon2);
  }
}

export const geoService = new GeoService();

