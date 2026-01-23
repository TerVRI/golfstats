'use client';

import { useGPSTracking } from '@/hooks/use-gps-tracking';
import { GreenLocation, formatDistance, formatAccuracy } from '@/lib/gps-tracking';
import { cn } from '@/lib/utils';

interface LiveDistanceDisplayProps {
  greenLocation: GreenLocation | null;
  className?: string;
  compact?: boolean;
  onShotMarked?: (shot: { club?: string }) => void;
}

export function LiveDistanceDisplay({
  greenLocation,
  className,
  compact = false,
  onShotMarked,
}: LiveDistanceDisplayProps) {
  const {
    status,
    position,
    error,
    accuracy,
    distanceToGreen,
    lastShotDistance,
    isTracking,
    startTracking,
    stopTracking,
    markShot,
  } = useGPSTracking({ greenLocation });

  const handleMarkShot = () => {
    const shot = markShot();
    if (shot) {
      onShotMarked?.({ club: shot.club });
    }
  };

  // Status indicator colors
  const statusColors = {
    idle: 'bg-gray-500',
    requesting: 'bg-yellow-500 animate-pulse',
    tracking: accuracy === 'high' ? 'bg-green-500' : accuracy === 'medium' ? 'bg-yellow-500' : 'bg-orange-500',
    error: 'bg-red-500',
    denied: 'bg-red-500',
    unavailable: 'bg-gray-500',
  };

  if (compact) {
    return (
      <div className={cn('flex items-center gap-3', className)}>
        {/* Status dot */}
        <div className={cn('w-2 h-2 rounded-full', statusColors[status])} />
        
        {/* Distance */}
        {distanceToGreen ? (
          <span className="font-mono text-lg font-bold">
            {formatDistance(distanceToGreen.center)}y
          </span>
        ) : (
          <span className="text-muted-foreground">--</span>
        )}
        
        {/* Start/Stop button */}
        {!isTracking ? (
          <button
            onClick={startTracking}
            className="text-xs px-2 py-1 bg-green-600 text-white rounded hover:bg-green-700"
          >
            Start GPS
          </button>
        ) : (
          <button
            onClick={stopTracking}
            className="text-xs px-2 py-1 bg-gray-600 text-white rounded hover:bg-gray-700"
          >
            Stop
          </button>
        )}
      </div>
    );
  }

  return (
    <div className={cn('bg-card rounded-lg border p-4', className)}>
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-semibold">Live Distance</h3>
        <div className="flex items-center gap-2">
          <div className={cn('w-2 h-2 rounded-full', statusColors[status])} />
          <span className="text-xs text-muted-foreground">
            {status === 'tracking' ? formatAccuracy(position?.accuracy || 0) : status}
          </span>
        </div>
      </div>

      {/* Error message */}
      {error && (
        <div className="mb-4 p-2 bg-red-500/10 border border-red-500/20 rounded text-sm text-red-600">
          {error}
        </div>
      )}

      {/* Main content */}
      {status === 'idle' || status === 'unavailable' || status === 'denied' ? (
        <div className="text-center py-6">
          {status === 'unavailable' ? (
            <p className="text-muted-foreground mb-4">
              GPS is not available in this browser
            </p>
          ) : status === 'denied' ? (
            <p className="text-muted-foreground mb-4">
              Location permission denied. Enable in browser settings.
            </p>
          ) : (
            <p className="text-muted-foreground mb-4">
              Start GPS to see live distances
            </p>
          )}
          {status !== 'unavailable' && status !== 'denied' && (
            <button
              onClick={startTracking}
              className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
            >
              Start GPS Tracking
            </button>
          )}
        </div>
      ) : status === 'requesting' ? (
        <div className="text-center py-6">
          <div className="animate-spin w-8 h-8 border-2 border-green-500 border-t-transparent rounded-full mx-auto mb-4" />
          <p className="text-muted-foreground">Getting location...</p>
        </div>
      ) : (
        <>
          {/* Distances */}
          {distanceToGreen && greenLocation ? (
            <div className="grid grid-cols-3 gap-4 mb-4">
              <div className="text-center">
                <div className="text-xs text-muted-foreground uppercase mb-1">Front</div>
                <div className="text-xl font-bold text-blue-500">
                  {formatDistance(distanceToGreen.front)}
                </div>
                <div className="text-xs text-muted-foreground">yds</div>
              </div>
              <div className="text-center">
                <div className="text-xs text-muted-foreground uppercase mb-1">Center</div>
                <div className="text-3xl font-bold text-green-500">
                  {formatDistance(distanceToGreen.center)}
                </div>
                <div className="text-xs text-muted-foreground">yds</div>
              </div>
              <div className="text-center">
                <div className="text-xs text-muted-foreground uppercase mb-1">Back</div>
                <div className="text-xl font-bold text-orange-500">
                  {formatDistance(distanceToGreen.back)}
                </div>
                <div className="text-xs text-muted-foreground">yds</div>
              </div>
            </div>
          ) : (
            <div className="text-center py-4 text-muted-foreground">
              No green location data available
            </div>
          )}

          {/* Last shot distance */}
          {lastShotDistance !== null && (
            <div className="text-center mb-4 p-2 bg-muted rounded">
              <div className="text-xs text-muted-foreground">Last Shot</div>
              <div className="text-lg font-semibold">{lastShotDistance} yards</div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-2">
            <button
              onClick={handleMarkShot}
              className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
            >
              Mark Shot Here
            </button>
            <button
              onClick={stopTracking}
              className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition"
            >
              Stop
            </button>
          </div>
        </>
      )}
    </div>
  );
}

// Minimal distance badge for use in other components
export function DistanceBadge({
  greenLocation,
  className,
}: {
  greenLocation: GreenLocation | null;
  className?: string;
}) {
  const { distanceToGreen, status, startTracking } = useGPSTracking({ greenLocation, autoStart: true });

  if (status !== 'tracking' || !distanceToGreen) {
    return (
      <button
        onClick={startTracking}
        className={cn(
          'inline-flex items-center gap-1 px-2 py-1 text-xs bg-muted rounded',
          className
        )}
      >
        <span className="w-1.5 h-1.5 bg-gray-500 rounded-full" />
        GPS Off
      </button>
    );
  }

  return (
    <div className={cn('inline-flex items-center gap-1 px-2 py-1 text-xs bg-green-500/10 rounded', className)}>
      <span className="w-1.5 h-1.5 bg-green-500 rounded-full" />
      <span className="font-mono font-bold">{distanceToGreen.center}y</span>
    </div>
  );
}
