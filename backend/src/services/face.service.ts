import { userRepository } from '../repositories/user.repository';
import { cosineSimilarity } from '../utils/math';
import { FACE_MATCH_THRESHOLD, MOBILE_FACENET_EMBEDDING_DIM } from '../config';
import { UserFaceRecord } from '../types';

export class FaceService {
  async registerFace(
    userId: string,
    name: string,
    embedding: number[]
  ): Promise<UserFaceRecord> {
    if (!userId || !userId.trim()) {
      throw new Error('UserId không được để trống');
    }

    if (!Array.isArray(embedding) || embedding.length !== MOBILE_FACENET_EMBEDDING_DIM) {
      throw new Error(
        `Vector khuôn mặt không hợp lệ: Yêu cầu mảng ${MOBILE_FACENET_EMBEDDING_DIM} chiều từ MobileFaceNet`
      );
    }

    return await userRepository.saveUser(userId.trim(), name || 'Nhân viên', embedding);
  }

  async verifyFace(
    userId: string,
    embedding: number[]
  ): Promise<{
    matched: boolean;
    similarity: number;
    threshold: number;
    user: UserFaceRecord | null;
  }> {
    const user = await userRepository.findByUserId(userId);
    if (!user) {
      return {
        matched: false,
        similarity: -1,
        threshold: FACE_MATCH_THRESHOLD,
        user: null
      };
    }

    const similarity = cosineSimilarity(user.faceEmbedding, embedding);
    return {
      matched: similarity >= FACE_MATCH_THRESHOLD,
      similarity: Number(similarity.toFixed(4)),
      threshold: FACE_MATCH_THRESHOLD,
      user
    };
  }

  async getUser(userId: string): Promise<UserFaceRecord | null> {
    return await userRepository.findByUserId(userId);
  }

  async getAllUsers(): Promise<Omit<UserFaceRecord, 'faceEmbedding'>[]> {
    return await userRepository.findAll();
  }
}

export const faceService = new FaceService();

