import { OfficeConfig } from '../types';

/**
 * Tính khoảng cách giữa 2 tọa độ GPS bằng công thức Haversine (đơn vị: mét)
 */
export function calculateDistanceInMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371e3; // Bán kính Trái Đất (mét)
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) *
      Math.cos(phi2) *
      Math.sin(deltaLambda / 2) *
      Math.sin(deltaLambda / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

// Giữ lại alias calculateDistanceMeters cho tương thích ngược
export const calculateDistanceMeters = calculateDistanceInMeters;

/**
 * Kiểm tra xem vị trí có nằm trong vùng Geofence hay không
 */
export function isWithinGeofence(
  lat: number,
  lng: number,
  office: OfficeConfig
): { isInside: boolean; distanceMeters: number } {
  const distance = calculateDistanceInMeters(lat, lng, office.lat, office.lng);
  return {
    isInside: distance <= office.maxRadiusMeters,
    distanceMeters: distance
  };
}
