import { z } from 'zod';
import { faceService } from '../services/face.service';
import { MOBILE_FACENET_EMBEDDING_DIM } from '../config';

// Zod Schemas
export const RegisterFaceSchema = z.object({
  userId: z.string().describe('Mã định danh của nhân viên (ví dụ: NV001)'),
  name: z.string().optional().describe('Họ và tên của nhân viên'),
  embedding: z
    .array(z.number())
    .length(MOBILE_FACENET_EMBEDDING_DIM)
    .describe(`Mảng vector khuôn mặt gồm đúng ${MOBILE_FACENET_EMBEDDING_DIM} phần tử số thực`)
});

export const VerifyFaceSchema = z.object({
  userId: z.string().describe('Mã định danh nhân viên cần đối chiếu'),
  embedding: z
    .array(z.number())
    .length(MOBILE_FACENET_EMBEDDING_DIM)
    .describe(`Mảng vector khuôn mặt cần so khớp (${MOBILE_FACENET_EMBEDDING_DIM} chiều)`)
});

// Definitions for ListTools
export const faceToolsDefinitions = [
  {
    name: 'register_face',
    description: 'Đăng ký vector khuôn mặt MobileFaceNet (192 chiều) cho người dùng/nhân viên.',
    inputSchema: {
      type: 'object',
      properties: {
        userId: { type: 'string', description: 'Mã định danh của nhân viên' },
        name: { type: 'string', description: 'Họ và tên của nhân viên' },
        embedding: {
          type: 'array',
          items: { type: 'number' },
          description: `Mảng vector 192 phần tử số thực từ MobileFaceNet`
        }
      },
      required: ['userId', 'embedding']
    }
  },
  {
    name: 'verify_face',
    description: 'Đối chiếu vector khuôn mặt gửi lên với vector đã đăng ký của nhân viên bằng Cosine Similarity.',
    inputSchema: {
      type: 'object',
      properties: {
        userId: { type: 'string', description: 'Mã định danh nhân viên cần đối chiếu' },
        embedding: {
          type: 'array',
          items: { type: 'number' },
          description: `Mảng vector khuôn mặt cần so khớp (${MOBILE_FACENET_EMBEDDING_DIM} chiều)`
        }
      },
      required: ['userId', 'embedding']
    }
  }
];

// Handlers
export async function handleRegisterFace(args: unknown) {
  const { userId, name, embedding } = RegisterFaceSchema.parse(args);
  const record = await faceService.registerFace(userId, name || 'Nhân viên', embedding);

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            success: true,
            message: `Đăng ký khuôn mặt thành công cho ${userId} (${record.name})`,
            data: {
              userId: record.userId,
              name: record.name,
              dimensions: record.faceEmbedding.length,
              registeredAt: record.registeredAt
            }
          },
          null,
          2
        )
      }
    ]
  };
}

export async function handleVerifyFace(args: unknown) {
  const { userId, embedding } = VerifyFaceSchema.parse(args);
  const result = await faceService.verifyFace(userId, embedding);

  if (!result.user) {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(
            {
              success: false,
              message: `Không tìm thấy thông tin đăng ký khuôn mặt cho user: ${userId}`
            },
            null,
            2
          )
        }
      ]
    };
  }

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            success: result.matched,
            userId,
            name: result.user.name,
            similarity: result.similarity,
            similarityPercentage: `${(result.similarity * 100).toFixed(2)}%`,
            threshold: result.threshold,
            status: result.matched ? 'MATCHED' : 'NOT_MATCHED'
          },
          null,
          2
        )
      }
    ]
  };
}
