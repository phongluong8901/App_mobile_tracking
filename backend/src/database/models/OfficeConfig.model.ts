import mongoose, { Schema, Document } from 'mongoose';
import { OfficeConfig } from '../../types';

export interface IOfficeConfigDocument extends Document, OfficeConfig {
  key: string;
}

const OfficeConfigSchema = new Schema<IOfficeConfigDocument>(
  {
    key: { type: String, required: true, unique: true, default: 'primary' },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    maxRadiusMeters: { type: Number, required: true },
    name: { type: String, default: 'Trụ sở công ty' }
  },
  {
    timestamps: true
  }
);

export const OfficeConfigModel = mongoose.model<IOfficeConfigDocument>(
  'OfficeConfig',
  OfficeConfigSchema
);
