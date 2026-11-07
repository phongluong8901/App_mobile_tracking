#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  ListPromptsRequestSchema,
  GetPromptRequestSchema,
  ErrorCode,
  McpError
} from '@modelcontextprotocol/sdk/types.js';

import { connectMongo, disconnectMongo } from './database/mongo';
import {
  faceToolsDefinitions,
  handleRegisterFace,
  handleVerifyFace
} from './tools/face.tools';
import {
  checkInToolsDefinitions,
  handleCheckIn,
  handleGetAttendanceLogs
} from './tools/checkin.tools';
import {
  geoToolsDefinitions,
  handleCheckGeofence,
  handleUpdateOfficeLocation,
  handleTrackLiveLocation
} from './tools/geo.tools';
import {
  attendanceResourcesDefinitions,
  handleReadResource
} from './resources/attendance.resources';
import {
  attendancePromptsDefinitions,
  handleGetPrompt
} from './prompts/attendance.prompts';

async function main(): Promise<void> {
  // 1. Kết nối MongoDB Atlas
  await connectMongo();

  // 2. Khởi tạo MCP Server chuẩn
  const server = new Server(
    {
      name: 'attendance-mcp-server',
      version: '1.0.0'
    },
    {
      capabilities: {
        tools: {},
        resources: {},
        prompts: {}
      }
    }
  );

  // 3. Đăng ký Handler danh sách Tools
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: [
        ...faceToolsDefinitions,
        ...checkInToolsDefinitions,
        ...geoToolsDefinitions
      ]
    };
  });

  // 4. Đăng ký Handler thực thi Tools
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      switch (name) {
        case 'register_face':
          return await handleRegisterFace(args);
        case 'verify_face':
          return await handleVerifyFace(args);
        case 'check_in':
          return await handleCheckIn(args);
        case 'get_attendance_logs':
          return await handleGetAttendanceLogs(args);
        case 'check_geofence':
          return await handleCheckGeofence(args);
        case 'update_office_location':
          return await handleUpdateOfficeLocation(args);
        case 'track_live_location':
          return await handleTrackLiveLocation(args);
        default:
          throw new McpError(
            ErrorCode.MethodNotFound,
            `Tool không xác định: ${name}`
          );
      }
    } catch (error: any) {
      if (error instanceof McpError) {
        throw error;
      }
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(
              {
                success: false,
                error: error.message || 'Lỗi không xác định khi thực thi tool'
              },
              null,
              2
            )
          }
        ],
        isError: true
      };
    }
  });

  // 5. Đăng ký Handler Resources
  server.setRequestHandler(ListResourcesRequestSchema, async () => {
    return {
      resources: attendanceResourcesDefinitions
    };
  });

  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    return await handleReadResource(request.params.uri);
  });

  // 6. Đăng ký Handler Prompts
  server.setRequestHandler(ListPromptsRequestSchema, async () => {
    return {
      prompts: attendancePromptsDefinitions
    };
  });

  server.setRequestHandler(GetPromptRequestSchema, async (request) => {
    return await handleGetPrompt(request.params.name, request.params.arguments);
  });

  // 7. Khởi tạo Transport Stdio và lắng nghe
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error('[MCP SERVER] Attendance & Face Recognition MCP Server đang chạy qua stdio');

  // Graceful shutdown
  const handleExit = async () => {
    console.error('[MCP SERVER] Đang tắt server và ngắt kết nối DB...');
    await disconnectMongo();
    process.exit(0);
  };

  process.on('SIGINT', handleExit);
  process.on('SIGTERM', handleExit);
}

main().catch((error) => {
  console.error('[MCP SERVER FATAL ERROR]', error);
  process.exit(1);
});
