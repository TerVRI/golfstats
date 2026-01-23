/**
 * Live GPS Tracking for Web App
 * Enables in-round GPS tracking on browsers (including laptop browsers)
 */

export interface GPSPosition {
  latitude: number;
  longitude: number;
  accuracy: number; // meters
  altitude?: number;
  altitudeAccuracy?: number;
  heading?: number;
  speed?: number;
  timestamp: number;
}

export interface GreenLocation {
  front: { lat: number; lon: number };
  center: { lat: number; lon: number };
  back: { lat: number; lon: number };
}

export interface DistanceToGreen {
  front: number;
  center: number;
  back: number;
}

export interface Shot {
  id: string;
  holeNumber: number;
  shotNumber: number;
  position: GPSPosition;
  club?: string;
  distance?: number; // distance from previous shot
  timestamp: number;
}

export type GPSStatus = 'idle' | 'requesting' | 'tracking' | 'error' | 'denied' | 'unavailable';

export interface GPSTrackingState {
  status: GPSStatus;
  position: GPSPosition | null;
  error: string | null;
  accuracy: 'high' | 'medium' | 'low' | 'unknown';
}

// Check if geolocation is available
export function isGeolocationAvailable(): boolean {
  return 'geolocation' in navigator;
}

// Request geolocation permission
export async function requestGeolocationPermission(): Promise<PermissionState> {
  if (!isGeolocationAvailable()) {
    return 'denied';
  }

  try {
    const result = await navigator.permissions.query({ name: 'geolocation' });
    return result.state;
  } catch {
    // Fallback for browsers that don't support permissions API
    return 'prompt';
  }
}

// Get current position (one-time)
export function getCurrentPosition(options?: PositionOptions): Promise<GPSPosition> {
  return new Promise((resolve, reject) => {
    if (!isGeolocationAvailable()) {
      reject(new Error('Geolocation is not available'));
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          altitude: position.coords.altitude ?? undefined,
          altitudeAccuracy: position.coords.altitudeAccuracy ?? undefined,
          heading: position.coords.heading ?? undefined,
          speed: position.coords.speed ?? undefined,
          timestamp: position.timestamp,
        });
      },
      (error) => {
        reject(new Error(getGeolocationErrorMessage(error)));
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0,
        ...options,
      }
    );
  });
}

// Watch position (continuous tracking)
export function watchPosition(
  onPosition: (position: GPSPosition) => void,
  onError: (error: string) => void,
  options?: PositionOptions
): number {
  if (!isGeolocationAvailable()) {
    onError('Geolocation is not available');
    return -1;
  }

  return navigator.geolocation.watchPosition(
    (position) => {
      onPosition({
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy,
        altitude: position.coords.altitude ?? undefined,
        altitudeAccuracy: position.coords.altitudeAccuracy ?? undefined,
        heading: position.coords.heading ?? undefined,
        speed: position.coords.speed ?? undefined,
        timestamp: position.timestamp,
      });
    },
    (error) => {
      onError(getGeolocationErrorMessage(error));
    },
    {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 1000, // Allow 1 second cache for smoother updates
      ...options,
    }
  );
}

// Stop watching position
export function clearWatch(watchId: number): void {
  if (watchId >= 0) {
    navigator.geolocation.clearWatch(watchId);
  }
}

// Calculate distance between two coordinates (in yards)
export function calculateDistance(
  from: { latitude: number; longitude: number },
  to: { lat: number; lon: number }
): number {
  const R = 6371000; // Earth's radius in meters
  const φ1 = (from.latitude * Math.PI) / 180;
  const φ2 = (to.lat * Math.PI) / 180;
  const Δφ = ((to.lat - from.latitude) * Math.PI) / 180;
  const Δλ = ((to.lon - from.longitude) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const meters = R * c;

  // Convert to yards
  return Math.round(meters * 1.09361);
}

// Calculate distances to green
export function calculateDistancesToGreen(
  position: GPSPosition,
  green: GreenLocation
): DistanceToGreen {
  return {
    front: calculateDistance(position, green.front),
    center: calculateDistance(position, green.center),
    back: calculateDistance(position, green.back),
  };
}

// Calculate distance between two shots
export function calculateShotDistance(from: GPSPosition, to: GPSPosition): number {
  return calculateDistance(from, { lat: to.latitude, lon: to.longitude });
}

// Get accuracy level from meters
export function getAccuracyLevel(accuracy: number): 'high' | 'medium' | 'low' {
  if (accuracy <= 10) return 'high';
  if (accuracy <= 50) return 'medium';
  return 'low';
}

// Get user-friendly error message
function getGeolocationErrorMessage(error: GeolocationPositionError): string {
  switch (error.code) {
    case error.PERMISSION_DENIED:
      return 'Location permission denied. Please enable location access in your browser settings.';
    case error.POSITION_UNAVAILABLE:
      return 'Location information unavailable. Check your device\'s location settings.';
    case error.TIMEOUT:
      return 'Location request timed out. Please try again.';
    default:
      return 'An unknown error occurred while getting location.';
  }
}

// Format distance for display
export function formatDistance(yards: number): string {
  if (yards < 0) return '--';
  return `${yards}`;
}

// Format accuracy for display
export function formatAccuracy(accuracy: number): string {
  if (accuracy < 10) return `±${Math.round(accuracy)}m (GPS)`;
  if (accuracy < 50) return `±${Math.round(accuracy)}m (WiFi)`;
  return `±${Math.round(accuracy)}m (approx)`;
}

// Check if position is on course (within reasonable distance)
export function isOnCourse(
  position: GPSPosition,
  courseCenter: { lat: number; lon: number },
  maxDistanceYards: number = 1000
): boolean {
  const distance = calculateDistance(position, courseCenter);
  return distance <= maxDistanceYards;
}

// Bearing calculation (for direction to target)
export function calculateBearing(
  from: GPSPosition,
  to: { lat: number; lon: number }
): number {
  const φ1 = (from.latitude * Math.PI) / 180;
  const φ2 = (to.lat * Math.PI) / 180;
  const Δλ = ((to.lon - from.longitude) * Math.PI) / 180;

  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);

  const θ = Math.atan2(y, x);
  const bearing = ((θ * 180) / Math.PI + 360) % 360;

  return bearing;
}

// Get compass direction from bearing
export function getCompassDirection(bearing: number): string {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  const index = Math.round(bearing / 45) % 8;
  return directions[index];
}
