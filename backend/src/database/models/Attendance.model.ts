import mongoose, { Schema, Document } from 'mongoose';
import { AttendanceRecord } from '../../types';

export interface IAttendanceDocument extends Document, AttendanceRecord {}

const AttendanceSchema = new Schema<IAttendanceDocument>(
  {
    id: { type: Number, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    name: { type: String },
    type: {
      type: String,
      enum: [
        'MORNING_IN',
        'MORNING_OUT',
        'AFTERNOON_IN',
        'AFTERNOON_OUT',
        'CHECK_IN',
        'CHECK_OUT'
      ],
      default: 'MORNING_IN'
    },
    shiftStatus: {
      type: String,
      enum: ['ON_TIME', 'LATE', 'EARLY_LEAVE', 'OVERTIME'],
      default: 'ON_TIME'
    },
    lateMinutes: { type: Number, default: 0 },
    earlyLeaveMinutes: { type: Number, default: 0 },
    workedHours: { type: Number, default: 0 },
    workUnits: { type: Number, default: 0 },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    distance: { type: Number, required: true },
    similarity: { type: Number, required: true },
    deviceId: { type: String },
    timestamp: { type: String, required: true, index: true },
    status: {
      type: String,
      enum: ['SUCCESS', 'REJECTED'],
      required: true,
      default: 'SUCCESS'
    },
    rejectionReason: { type: String }
  },
  {
    timestamps: true
  }
);

export const AttendanceModel = mongoose.model<IAttendanceDocument>(
  'Attendance',
  AttendanceSchema
);
