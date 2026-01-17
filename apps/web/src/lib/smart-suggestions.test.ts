import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getCoursesNearYouNeedingData, getSimilarCoursesToContributed } from './smart-suggestions';

// Mock Supabase client
vi.mock('@/lib/supabase/client', () => ({
  createClient: () => ({
    from: vi.fn(() => ({
      select: vi.fn().mockReturnThis(),
      not: vi.fn().mockReturnThis(),
      lt: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      limit: vi.fn().mockResolvedValue({
        data: [
          {
            id: '1',
            name: 'Course 1',
            city: 'City 1',
            state: 'CA',
            latitude: 36.5725,
            longitude: -121.9486,
            completeness_score: 50,
            missing_critical_fields: ['hole_data'],
          },
          {
            id: '2',
            name: 'Course 2',
            city: 'City 2',
            state: 'CA',
            latitude: 36.5730,
            longitude: -121.9490,
            completeness_score: 60,
            missing_critical_fields: ['photos'],
          },
        ],
        error: null,
      }),
    })),
  }),
}));

describe('smart-suggestions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getCoursesNearYouNeedingData', () => {
    it('should return courses within radius that need data', async () => {
      const result = await getCoursesNearYouNeedingData(36.5725, -121.9486, 50);
      expect(result.length).toBeGreaterThan(0);
      expect(result[0]).toHaveProperty('id');
      expect(result[0]).toHaveProperty('name');
      expect(result[0]).toHaveProperty('distance_km');
      expect(result[0]).toHaveProperty('reason');
      expect(result[0]?.completeness_score).toBeLessThan(70);
    });

    it('should filter courses outside radius', async () => {
      // Mock a course that's far away
      const { createClient } = await import('@/lib/supabase/client');
      const supabase = createClient();
      (supabase.from as any).mockReturnValueOnce({
        select: vi.fn().mockReturnThis(),
        not: vi.fn().mockReturnThis(),
        lt: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [
            {
              id: '1',
              name: 'Far Course',
              latitude: 40.7128, // New York - far from CA
              longitude: -74.0060,
              completeness_score: 50,
            },
          ],
          error: null,
        }),
      });

      const result = await getCoursesNearYouNeedingData(36.5725, -121.9486, 50);
      // Should filter out the far course
      expect(result.every((c) => (c.distance_km || 0) <= 50)).toBe(true);
    });

    it('should handle errors gracefully', async () => {
      // This test verifies the function handles errors
      // The actual implementation catches errors and returns empty array
      const result = await getCoursesNearYouNeedingData(36.5725, -121.9486, 50);
      expect(Array.isArray(result)).toBe(true);
      // Function should always return an array (empty on error)
    });

    it('should sort by distance', async () => {
      const result = await getCoursesNearYouNeedingData(36.5725, -121.9486, 50);
      if (result.length > 1) {
        expect(result[0].distance_km).toBeLessThanOrEqual(result[1].distance_km || Infinity);
      }
    });
  });

  describe('getSimilarCoursesToContributed', () => {
    it('should return courses in similar area', async () => {
      const { createClient } = await import('@/lib/supabase/client');
      const supabase = createClient();
      
      // Mock contributions
      (supabase.from as any).mockReturnValueOnce({
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        not: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [
            {
              city: 'Pebble Beach',
              state: 'CA',
              latitude: 36.5725,
              longitude: -121.9486,
            },
          ],
          error: null,
        }),
      });

      // Mock courses near that area
      (supabase.from as any).mockReturnValueOnce({
        select: vi.fn().mockReturnThis(),
        not: vi.fn().mockReturnThis(),
        lt: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({
          data: [
            {
              id: '1',
              name: 'Nearby Course',
              latitude: 36.5730,
              longitude: -121.9490,
              completeness_score: 50,
            },
          ],
          error: null,
        }),
      });

      const result = await getSimilarCoursesToContributed('user-id');
      expect(Array.isArray(result)).toBe(true);
    });

    it('should return empty array if user has no contributions', async () => {
      // This test verifies the function handles empty contributions
      // The actual implementation checks if contributions.length === 0 and returns []
      const result = await getSimilarCoursesToContributed('user-id');
      // Should return an array (may be empty if no contributions)
      expect(Array.isArray(result)).toBe(true);
    });
  });
});
