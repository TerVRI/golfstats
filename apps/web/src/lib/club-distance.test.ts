import { describe, it, expect, beforeEach } from 'vitest';

// Club distance tracking utilities for web

interface ClubShot {
  club: string;
  distance: number;
  timestamp: Date;
}

interface ClubStats {
  totalShots: number;
  averageDistance: number;
  maxDistance: number;
  minDistance: number;
  standardDeviation: number;
}

const DEFAULT_DISTANCES: Record<string, number> = {
  'Driver': 230,
  '3W': 210,
  '5W': 195,
  '4H': 185,
  '5H': 175,
  '4i': 170,
  '5i': 160,
  '6i': 150,
  '7i': 140,
  '8i': 130,
  '9i': 120,
  'PW': 110,
  'GW': 100,
  'SW': 90,
  'LW': 75,
  'Putter': 0,
};

class ClubDistanceTracker {
  private shots: ClubShot[] = [];
  private clubStats: Map<string, ClubStats> = new Map();

  recordShot(club: string, distance: number): void {
    const shot: ClubShot = {
      club,
      distance,
      timestamp: new Date(),
    };
    this.shots.push(shot);
    this.updateStats(club);
  }

  private updateStats(club: string): void {
    const clubShots = this.shots.filter(s => s.club === club);
    if (clubShots.length === 0) return;

    const distances = clubShots.map(s => s.distance);
    const avg = distances.reduce((a, b) => a + b, 0) / distances.length;
    const max = Math.max(...distances);
    const min = Math.min(...distances);
    
    // Calculate standard deviation
    const squareDiffs = distances.map(d => Math.pow(d - avg, 2));
    const avgSquareDiff = squareDiffs.reduce((a, b) => a + b, 0) / distances.length;
    const stdDev = Math.sqrt(avgSquareDiff);

    this.clubStats.set(club, {
      totalShots: clubShots.length,
      averageDistance: Math.round(avg),
      maxDistance: max,
      minDistance: min,
      standardDeviation: stdDev,
    });
  }

  getStats(club: string): ClubStats | undefined {
    return this.clubStats.get(club);
  }

  getAverageDistance(club: string): number {
    const stats = this.clubStats.get(club);
    return stats?.averageDistance ?? DEFAULT_DISTANCES[club] ?? 0;
  }

  suggestClub(targetDistance: number): string {
    let closestClub = 'Driver';
    let smallestDiff = Infinity;

    for (const [club, defaultDist] of Object.entries(DEFAULT_DISTANCES)) {
      if (club === 'Putter') continue;
      
      const avg = this.getAverageDistance(club);
      const diff = Math.abs(avg - targetDistance);
      
      if (diff < smallestDiff) {
        smallestDiff = diff;
        closestClub = club;
      }
    }

    return closestClub;
  }

  getConsistencyScore(club: string): number {
    const stats = this.clubStats.get(club);
    if (!stats || stats.totalShots < 3) return 0;
    
    // Higher consistency = lower std dev relative to average
    const coefficientOfVariation = stats.standardDeviation / stats.averageDistance;
    return Math.max(0, Math.round(100 * (1 - coefficientOfVariation * 3)));
  }

  getAllClubStats(): Array<{ club: string; stats: ClubStats }> {
    return Array.from(this.clubStats.entries())
      .map(([club, stats]) => ({ club, stats }))
      .sort((a, b) => b.stats.averageDistance - a.stats.averageDistance);
  }

  clearAllData(): void {
    this.shots = [];
    this.clubStats.clear();
  }

  getRecentShots(limit: number = 10): ClubShot[] {
    return this.shots.slice(-limit);
  }
}

describe('ClubDistanceTracker', () => {
  let tracker: ClubDistanceTracker;

  beforeEach(() => {
    tracker = new ClubDistanceTracker();
  });

  describe('Recording shots', () => {
    it('should record a shot', () => {
      tracker.recordShot('7i', 145);
      const stats = tracker.getStats('7i');
      
      expect(stats).toBeDefined();
      expect(stats?.totalShots).toBe(1);
      expect(stats?.averageDistance).toBe(145);
    });

    it('should record multiple shots', () => {
      tracker.recordShot('7i', 145);
      tracker.recordShot('7i', 150);
      tracker.recordShot('7i', 140);
      
      const stats = tracker.getStats('7i');
      expect(stats?.totalShots).toBe(3);
      expect(stats?.averageDistance).toBe(145);
    });

    it('should calculate min/max correctly', () => {
      tracker.recordShot('Driver', 240);
      tracker.recordShot('Driver', 260);
      tracker.recordShot('Driver', 235);
      tracker.recordShot('Driver', 255);
      
      const stats = tracker.getStats('Driver');
      expect(stats?.maxDistance).toBe(260);
      expect(stats?.minDistance).toBe(235);
    });
  });

  describe('Average distance', () => {
    it('should return recorded average when available', () => {
      tracker.recordShot('7i', 145);
      tracker.recordShot('7i', 150);
      tracker.recordShot('7i', 140);
      
      expect(tracker.getAverageDistance('7i')).toBe(145);
    });

    it('should return default distance when no data', () => {
      expect(tracker.getAverageDistance('7i')).toBe(140);
    });

    it('should return 0 for unknown club', () => {
      expect(tracker.getAverageDistance('UnknownClub')).toBe(0);
    });
  });

  describe('Club suggestion', () => {
    it('should suggest correct club for distance from defaults', () => {
      const suggested = tracker.suggestClub(145);
      expect(['7i', '6i', '8i']).toContain(suggested);
    });

    it('should suggest driver for long distances', () => {
      const suggested = tracker.suggestClub(250);
      expect(['Driver', '3W']).toContain(suggested);
    });

    it('should suggest wedge for short distances', () => {
      const suggested = tracker.suggestClub(85);
      expect(['SW', 'GW', 'LW']).toContain(suggested);
    });

    it('should use learned distances for suggestions', () => {
      // Train 8i to be 145 yards (vs default 130)
      tracker.recordShot('8i', 145);
      tracker.recordShot('8i', 147);
      tracker.recordShot('8i', 143);
      
      const suggested = tracker.suggestClub(145);
      expect(suggested).toBe('8i');
    });
  });

  describe('Consistency score', () => {
    it('should return 0 for insufficient data', () => {
      tracker.recordShot('7i', 145);
      expect(tracker.getConsistencyScore('7i')).toBe(0);
    });

    it('should return high score for consistent shots', () => {
      tracker.recordShot('7i', 150);
      tracker.recordShot('7i', 151);
      tracker.recordShot('7i', 149);
      tracker.recordShot('7i', 150);
      tracker.recordShot('7i', 152);
      
      const score = tracker.getConsistencyScore('7i');
      expect(score).toBeGreaterThan(80);
    });

    it('should return lower score for inconsistent shots', () => {
      // Very inconsistent: range from 100 to 200
      tracker.recordShot('7i', 100);
      tracker.recordShot('7i', 200);
      tracker.recordShot('7i', 120);
      tracker.recordShot('7i', 180);
      tracker.recordShot('7i', 150);
      
      const score = tracker.getConsistencyScore('7i');
      // With high variance, consistency should be lower than consistent shots
      expect(score).toBeLessThan(80);
    });
  });

  describe('Data management', () => {
    it('should clear all data', () => {
      tracker.recordShot('7i', 145);
      tracker.recordShot('Driver', 250);
      
      tracker.clearAllData();
      
      expect(tracker.getStats('7i')).toBeUndefined();
      expect(tracker.getStats('Driver')).toBeUndefined();
      expect(tracker.getRecentShots()).toHaveLength(0);
    });

    it('should get recent shots', () => {
      tracker.recordShot('7i', 145);
      tracker.recordShot('8i', 130);
      tracker.recordShot('Driver', 250);
      
      const recent = tracker.getRecentShots(2);
      expect(recent).toHaveLength(2);
      expect(recent[0].club).toBe('8i');
      expect(recent[1].club).toBe('Driver');
    });

    it('should get all club stats sorted by distance', () => {
      tracker.recordShot('7i', 145);
      tracker.recordShot('Driver', 250);
      tracker.recordShot('PW', 110);
      
      const allStats = tracker.getAllClubStats();
      expect(allStats[0].club).toBe('Driver');
      expect(allStats[allStats.length - 1].club).toBe('PW');
    });
  });
});

describe('Default Distances', () => {
  it('should have driver as longest club', () => {
    const clubs = Object.entries(DEFAULT_DISTANCES)
      .filter(([club]) => club !== 'Putter')
      .sort((a, b) => b[1] - a[1]);
    
    expect(clubs[0][0]).toBe('Driver');
  });

  it('should have correct iron progression', () => {
    expect(DEFAULT_DISTANCES['5i']).toBeGreaterThan(DEFAULT_DISTANCES['6i']);
    expect(DEFAULT_DISTANCES['6i']).toBeGreaterThan(DEFAULT_DISTANCES['7i']);
    expect(DEFAULT_DISTANCES['7i']).toBeGreaterThan(DEFAULT_DISTANCES['8i']);
    expect(DEFAULT_DISTANCES['8i']).toBeGreaterThan(DEFAULT_DISTANCES['9i']);
  });

  it('should have wedges shorter than irons', () => {
    expect(DEFAULT_DISTANCES['PW']).toBeLessThan(DEFAULT_DISTANCES['9i']);
    expect(DEFAULT_DISTANCES['SW']).toBeLessThan(DEFAULT_DISTANCES['PW']);
  });
});
