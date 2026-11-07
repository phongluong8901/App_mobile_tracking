import mongoose, { Schema, Document } from 'mongoose';
import { LiveLocationRecord } from '../../types';

export interface ILiveLocationDocument extends Document, LiveLocationRecord {}

const LiveLocationSchema = new Schema<ILiveLocationDocument>(
  {
    userId: { type: String, required: true, unique: true, index: true },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    speed: { type: Number, default: 0 },
    timestamp: { type: String, required: true }
  },
  {
    timestamps: true
  }
);

export const LiveLocationModel = mongoose.model<ILiveLocationDocument>(
  'LiveLocation',
  LiveLocationSchema
);
