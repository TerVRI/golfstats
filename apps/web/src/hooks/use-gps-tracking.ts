'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import {
  GPSPosition,
  GPSStatus,
  GPSTrackingState,
  DistanceToGreen,
  GreenLocation,
  Shot,
  isGeolocationAvailable,
  watchPosition,
  clearWatch,
  getCurrentPosition,
  calculateDistancesToGreen,
  calculateShotDistance,
  getAccuracyLevel,
} from '@/lib/gps-tracking';

interface UseGPSTrackingOptions {
  autoStart?: boolean;
  greenLocation?: GreenLocation | null;
  onPositionUpdate?: (position: GPSPosition) => void;
  onError?: (error: string) => void;
}

interface UseGPSTrackingReturn {
  // State
  status: GPSStatus;
  position: GPSPosition | null;
  error: string | null;
  accuracy: 'high' | 'medium' | 'low' | 'unknown';
  isTracking: boolean;
  isAvailable: boolean;

  // Distances
  distanceToGreen: DistanceToGreen | null;

  // Shots
  shots: Shot[];
  lastShotDistance: number | null;

  // Actions
  startTracking: () => Promise<void>;
  stopTracking: () => void;
  markShot: (club?: string) => Shot | null;
  clearShots: () => void;
  getPosition: () => Promise<GPSPosition>;
}

export function useGPSTracking(options: UseGPSTrackingOptions = {}): UseGPSTrackingReturn {
  const { autoStart = false, greenLocation, onPositionUpdate, onError } = options;

  const [status, setStatus] = useState<GPSStatus>('idle');
  const [position, setPosition] = useState<GPSPosition | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [shots, setShots] = useState<Shot[]>([]);

  const watchIdRef = useRef<number>(-1);
  const isAvailable = isGeolocationAvailable();

  // Calculate accuracy level
  const accuracy = position ? getAccuracyLevel(position.accuracy) : 'unknown';

  // Calculate distance to green
  const distanceToGreen = position && greenLocation
    ? calculateDistancesToGreen(position, greenLocation)
    : null;

  // Calculate last shot distance
  const lastShotDistance = shots.length >= 2
    ? calculateShotDistance(shots[shots.length - 2].position, shots[shots.length - 1].position)
    : null;

  // Start tracking
  const startTracking = useCallback(async () => {
    if (!isAvailable) {
      setStatus('unavailable');
      setError('Geolocation is not available in this browser');
      return;
    }

    setStatus('requesting');
    setError(null);

    try {
      // Get initial position
      const initialPosition = await getCurrentPosition();
      setPosition(initialPosition);
      setStatus('tracking');
      onPositionUpdate?.(initialPosition);

      // Start continuous tracking
      watchIdRef.current = watchPosition(
        (pos) => {
          setPosition(pos);
          setError(null);
          onPositionUpdate?.(pos);
        },
        (err) => {
          setError(err);
          if (err.includes('denied')) {
            setStatus('denied');
          } else {
            setStatus('error');
          }
          onError?.(err);
        }
      );
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to get location';
      setError(errorMessage);
      if (errorMessage.includes('denied')) {
        setStatus('denied');
      } else {
        setStatus('error');
      }
      onError?.(errorMessage);
    }
  }, [isAvailable, onPositionUpdate, onError]);

  // Stop tracking
  const stopTracking = useCallback(() => {
    if (watchIdRef.current >= 0) {
      clearWatch(watchIdRef.current);
      watchIdRef.current = -1;
    }
    setStatus('idle');
  }, []);

  // Mark a shot at current position
  const markShot = useCallback((club?: string): Shot | null => {
    if (!position) return null;

    const currentHole = 1; // Would come from round context
    const shotNumber = shots.filter(s => s.holeNumber === currentHole).length + 1;

    const newShot: Shot = {
      id: `shot-${Date.now()}`,
      holeNumber: currentHole,
      shotNumber,
      position,
      club,
      distance: shots.length > 0
        ? calculateShotDistance(shots[shots.length - 1].position, position)
        : undefined,
      timestamp: Date.now(),
    };

    setShots(prev => [...prev, newShot]);
    return newShot;
  }, [position, shots]);

  // Clear all shots
  const clearShots = useCallback(() => {
    setShots([]);
  }, []);

  // Get current position (one-time)
  const getPosition = useCallback(async (): Promise<GPSPosition> => {
    return getCurrentPosition();
  }, []);

  // Auto-start if enabled
  useEffect(() => {
    if (autoStart && isAvailable) {
      startTracking();
    }

    return () => {
      stopTracking();
    };
  }, [autoStart, isAvailable, startTracking, stopTracking]);

  return {
    status,
    position,
    error,
    accuracy,
    isTracking: status === 'tracking',
    isAvailable,
    distanceToGreen,
    shots,
    lastShotDistance,
    startTracking,
    stopTracking,
    markShot,
    clearShots,
    getPosition,
  };
}

// Hook for just getting distances (no shot tracking)
export function useGPSDistance(greenLocation: GreenLocation | null) {
  const { position, distanceToGreen, status, accuracy, startTracking, stopTracking } = useGPSTracking({
    greenLocation,
  });

  return {
    position,
    distanceToGreen,
    status,
    accuracy,
    startTracking,
    stopTracking,
  };
}
