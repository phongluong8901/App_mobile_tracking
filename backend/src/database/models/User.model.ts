import mongoose, { Schema, Document } from 'mongoose';
import { UserFaceRecord } from '../../types';

export interface IUserDocument extends Document, Omit<UserFaceRecord, 'registeredAt'> {
  registeredAt: string;
}

const UserSchema = new Schema<IUserDocument>(
  {
    userId: { type: String, required: true, unique: true, index: true },
    name: { type: String, required: true },
    faceEmbedding: {
      type: [Number],
      required: true,
      validate: {
        validator: function (val: number[]) {
          return val.length === 192;
        },
        message: 'Vector khuôn mặt phải có đúng 192 chiều'
      }
    },
    registeredAt: { type: String, default: () => new Date().toISOString() }
  },
  {
    timestamps: true
  }
);

export const UserModel = mongoose.model<IUserDocument>('User', UserSchema);
