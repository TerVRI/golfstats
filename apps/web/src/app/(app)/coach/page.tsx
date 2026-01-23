'use client';

import { useState, useEffect } from 'react';
import { LiveDistanceDisplay } from '@/components/gps/live-distance-display';
import { AICaddiePanel } from '@/components/ai-caddie/ai-caddie-panel';
import { cn } from '@/lib/utils';

/**
 * Coach/Pro Dashboard
 * Optimized for large screens (laptops, tablets, displays)
 * Features:
 * - Live GPS tracking with large distance display
 * - AI Caddie recommendations
 * - Multi-player tracking (future)
 * - Shot visualization
 * - Real-time stats
 */

interface Player {
  id: string;
  name: string;
  currentHole: number;
  score: number;
  isActive: boolean;
}

export default function CoachDashboardPage() {
  const [selectedPlayer, setSelectedPlayer] = useState<string | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [currentHole, setCurrentHole] = useState(1);
  
  // Mock data - would come from real tracking
  const [players] = useState<Player[]>([
    { id: '1', name: 'Player 1', currentHole: 7, score: 2, isActive: true },
  ]);

  // Mock green location - would come from course data
  const greenLocation = {
    front: { lat: 36.5681, lon: -121.9486 },
    center: { lat: 36.5683, lon: -121.9488 },
    back: { lat: 36.5685, lon: -121.9490 },
  };

  // Toggle fullscreen
  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
      setIsFullscreen(true);
    } else {
      document.exitFullscreen();
      setIsFullscreen(false);
    }
  };

  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  return (
    <div className={cn(
      'min-h-screen bg-background',
      isFullscreen && 'fixed inset-0 z-50'
    )}>
      {/* Header */}
      <header className="border-b bg-card px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <h1 className="text-2xl font-bold">Coach Dashboard</h1>
            <span className="px-2 py-1 text-xs bg-green-500/10 text-green-600 rounded">
              Pro Mode
            </span>
          </div>
          
          <div className="flex items-center gap-4">
            {/* Hole selector */}
            <div className="flex items-center gap-2">
              <button
                onClick={() => setCurrentHole(h => Math.max(1, h - 1))}
                className="px-3 py-1 bg-muted rounded hover:bg-muted/80"
              >
                ←
              </button>
              <span className="font-mono font-bold min-w-[80px] text-center">
                Hole {currentHole}
              </span>
              <button
                onClick={() => setCurrentHole(h => Math.min(18, h + 1))}
                className="px-3 py-1 bg-muted rounded hover:bg-muted/80"
              >
                →
              </button>
            </div>

            {/* Fullscreen toggle */}
            <button
              onClick={toggleFullscreen}
              className="px-3 py-2 bg-muted rounded hover:bg-muted/80"
            >
              {isFullscreen ? '⛶ Exit Fullscreen' : '⛶ Fullscreen'}
            </button>
          </div>
        </div>
      </header>

      {/* Main content - 3-column layout for large screens */}
      <main className="grid grid-cols-1 lg:grid-cols-12 gap-6 p-6">
        {/* Left Panel - Players (2 cols) */}
        <aside className="lg:col-span-2 space-y-4">
          <div className="bg-card rounded-lg border p-4">
            <h2 className="font-semibold mb-4">Players</h2>
            <div className="space-y-2">
              {players.map(player => (
                <button
                  key={player.id}
                  onClick={() => setSelectedPlayer(player.id)}
                  className={cn(
                    'w-full p-3 rounded-lg text-left transition',
                    selectedPlayer === player.id
                      ? 'bg-green-500/20 border-green-500 border'
                      : 'bg-muted hover:bg-muted/80'
                  )}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{player.name}</span>
                    {player.isActive && (
                      <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                    )}
                  </div>
                  <div className="text-xs text-muted-foreground mt-1">
                    Hole {player.currentHole} • {player.score > 0 ? '+' : ''}{player.score}
                  </div>
                </button>
              ))}
            </div>
            
            <button className="w-full mt-4 p-2 border border-dashed rounded-lg text-muted-foreground hover:bg-muted/50 transition text-sm">
              + Add Player
            </button>
          </div>
        </aside>

        {/* Center Panel - Main Display (7 cols) */}
        <section className="lg:col-span-7 space-y-6">
          {/* Large Distance Display */}
          <div className="bg-card rounded-xl border p-8">
            <div className="text-center">
              <h2 className="text-lg text-muted-foreground mb-2">Distance to Green</h2>
              <LargeDistanceDisplay greenLocation={greenLocation} />
            </div>
          </div>

          {/* Course Map Placeholder */}
          <div className="bg-card rounded-xl border p-6 min-h-[400px] flex items-center justify-center">
            <div className="text-center text-muted-foreground">
              <div className="text-6xl mb-4">🗺️</div>
              <p>Course Map</p>
              <p className="text-sm">Shows player position, shots, and targets</p>
            </div>
          </div>

          {/* Shot History */}
          <div className="bg-card rounded-lg border p-4">
            <h3 className="font-semibold mb-4">Recent Shots</h3>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-muted-foreground">
                    <th className="pb-2">Shot</th>
                    <th className="pb-2">Club</th>
                    <th className="pb-2">Distance</th>
                    <th className="pb-2">Result</th>
                    <th className="pb-2">Time</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-t">
                    <td className="py-2">1</td>
                    <td className="py-2">Driver</td>
                    <td className="py-2">265y</td>
                    <td className="py-2 text-green-500">Fairway</td>
                    <td className="py-2 text-muted-foreground">2m ago</td>
                  </tr>
                  <tr className="border-t">
                    <td className="py-2">2</td>
                    <td className="py-2">7 Iron</td>
                    <td className="py-2">155y</td>
                    <td className="py-2 text-green-500">GIR</td>
                    <td className="py-2 text-muted-foreground">1m ago</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>

        {/* Right Panel - AI Caddie & Stats (3 cols) */}
        <aside className="lg:col-span-3 space-y-4">
          {/* AI Caddie */}
          <AICaddiePanel 
            distance={172}
            greenLocation={greenLocation}
          />

          {/* Quick Stats */}
          <div className="bg-card rounded-lg border p-4">
            <h3 className="font-semibold mb-4">Round Stats</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="text-center p-3 bg-muted rounded">
                <div className="text-2xl font-bold">7/10</div>
                <div className="text-xs text-muted-foreground">Fairways</div>
              </div>
              <div className="text-center p-3 bg-muted rounded">
                <div className="text-2xl font-bold">5/10</div>
                <div className="text-xs text-muted-foreground">GIR</div>
              </div>
              <div className="text-center p-3 bg-muted rounded">
                <div className="text-2xl font-bold">1.7</div>
                <div className="text-xs text-muted-foreground">Putts/Hole</div>
              </div>
              <div className="text-center p-3 bg-muted rounded">
                <div className="text-2xl font-bold text-green-500">+0.8</div>
                <div className="text-xs text-muted-foreground">Strokes Gained</div>
              </div>
            </div>
          </div>

          {/* Notes */}
          <div className="bg-card rounded-lg border p-4">
            <h3 className="font-semibold mb-4">Session Notes</h3>
            <textarea
              placeholder="Add notes about this session..."
              className="w-full h-24 p-2 text-sm bg-muted rounded resize-none"
            />
            <button className="w-full mt-2 p-2 bg-green-600 text-white rounded hover:bg-green-700 transition text-sm">
              Save Notes
            </button>
          </div>
        </aside>
      </main>
    </div>
  );
}

// Large distance display for coach view
function LargeDistanceDisplay({ greenLocation }: { greenLocation: typeof greenLocation }) {
  const { distanceToGreen, status, accuracy, startTracking } = useGPSTracking({
    greenLocation,
    autoStart: true,
  });

  if (status !== 'tracking' || !distanceToGreen) {
    return (
      <div className="py-8">
        <button
          onClick={startTracking}
          className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-lg"
        >
          Start GPS Tracking
        </button>
        <p className="text-sm text-muted-foreground mt-2">
          Enable location to see live distances
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Main center distance */}
      <div>
        <div className="text-8xl font-bold font-mono text-green-500">
          {distanceToGreen.center}
        </div>
        <div className="text-xl text-muted-foreground">yards to center</div>
      </div>

      {/* Front/Back */}
      <div className="flex justify-center gap-12">
        <div className="text-center">
          <div className="text-3xl font-bold text-blue-500">{distanceToGreen.front}</div>
          <div className="text-sm text-muted-foreground">Front</div>
        </div>
        <div className="text-center">
          <div className="text-3xl font-bold text-orange-500">{distanceToGreen.back}</div>
          <div className="text-sm text-muted-foreground">Back</div>
        </div>
      </div>

      {/* Accuracy indicator */}
      <div className="flex items-center justify-center gap-2 text-sm">
        <div className={cn(
          'w-2 h-2 rounded-full',
          accuracy === 'high' ? 'bg-green-500' : accuracy === 'medium' ? 'bg-yellow-500' : 'bg-orange-500'
        )} />
        <span className="text-muted-foreground">
          GPS Accuracy: {accuracy}
        </span>
      </div>
    </div>
  );
}

// Import the hook
import { useGPSTracking } from '@/hooks/use-gps-tracking';
