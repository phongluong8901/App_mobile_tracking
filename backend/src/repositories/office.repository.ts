import { OfficeConfigModel } from '../database/models/OfficeConfig.model';
import { OfficeConfig } from '../types';
import { DEFAULT_OFFICE_CONFIG } from '../config';
import { isMongoConnected } from '../database/mongo';

export class OfficeRepository {
  private memConfig: OfficeConfig = { ...DEFAULT_OFFICE_CONFIG };

  async getConfig(): Promise<OfficeConfig> {
    if (isMongoConnected()) {
      try {
        const found = await OfficeConfigModel.findOne({ key: 'primary' }).lean();
        if (found) {
          return {
            lat: found.lat,
            lng: found.lng,
            maxRadiusMeters: found.maxRadiusMeters,
            name: found.name || this.memConfig.name || 'Trụ sở công ty'
          };
        }
      } catch (err) {
        console.error('[OfficeRepository] Lỗi đọc OfficeConfig từ MongoDB Atlas:', err);
      }
    }
    return { ...this.memConfig };
  }

  async updateConfig(config: Partial<OfficeConfig>): Promise<OfficeConfig> {
    this.memConfig = {
      ...this.memConfig,
      ...config
    };

    if (isMongoConnected()) {
      try {
        await OfficeConfigModel.findOneAndUpdate(
          { key: 'primary' },
          {
            $set: {
              key: 'primary',
              lat: this.memConfig.lat,
              lng: this.memConfig.lng,
              maxRadiusMeters: this.memConfig.maxRadiusMeters,
              name: this.memConfig.name || 'Trụ sở công ty'
            }
          },
          { upsert: true, new: true }
        );
      } catch (err) {
        console.error('[OfficeRepository] Lỗi lưu OfficeConfig vào MongoDB Atlas:', err);
      }
    }

    return { ...this.memConfig };
  }
}

export const officeRepository = new OfficeRepository();

