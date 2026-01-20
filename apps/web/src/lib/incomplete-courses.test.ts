import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchIncompleteCourses, completeIncompleteCourse, geocodeAddress, getUserCompletions } from './incomplete-courses';

// Mock Supabase client
const mockSupabase = {
  from: vi.fn(),
  auth: {
    getUser: vi.fn(),
  },
};

vi.mock('@/lib/supabase/client', () => ({
  createClient: () => mockSupabase,
}));

describe('incomplete-courses', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('fetchIncompleteCourses', () => {
    it('should fetch incomplete courses with default options', async () => {
      const mockCourses = [
        {
          id: '1',
          name: 'Test Course',
          status: 'incomplete',
          completion_priority: 10,
          missing_fields: ['latitude', 'longitude'],
        },
      ];

      // Create a chainable mock - the query is awaited directly, so we need to make the chain resolve
      const mockQuery: any = {
        select: vi.fn().mockReturnThis(),
        in: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        gte: vi.fn().mockReturnThis(),
        contains: vi.fn().mockReturnThis(),
        limit: vi.fn().mockReturnThis(),
        range: vi.fn().mockReturnThis(),
      };
      
      // The query object itself is awaited, so we need to make it thenable
      mockQuery.then = vi.fn((resolve) => {
        resolve({ data: mockCourses, error: null });
        return mockQuery;
      });
      mockQuery.catch = vi.fn();
      
      mockSupabase.from.mockReturnValue(mockQuery);

      const result = await fetchIncompleteCourses();

      expect(result).toEqual(mockCourses);
      expect(mockSupabase.from).toHaveBeenCalledWith('course_contributions');
    });

    it('should filter by country when provided', async () => {
      mockSupabase.from.mockReturnValue({
        select: vi.fn().mockReturnThis(),
        in: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({ data: [], error: null }),
      });

      await fetchIncompleteCourses({ country: 'US' });

      expect(mockSupabase.from().eq).toHaveBeenCalledWith('country', 'US');
    });

    it('should filter by minPriority when provided', async () => {
      mockSupabase.from.mockReturnValue({
        select: vi.fn().mockReturnThis(),
        in: vi.fn().mockReturnThis(),
        gte: vi.fn().mockReturnThis(),
        order: vi.fn().mockReturnThis(),
        limit: vi.fn().mockResolvedValue({ data: [], error: null }),
      });

      await fetchIncompleteCourses({ minPriority: 7 });

      expect(mockSupabase.from().gte).toHaveBeenCalledWith('completion_priority', 7);
    });
  });

  describe('completeIncompleteCourse', () => {
    it('should complete a course with coordinates', async () => {
      const mockUser = { id: 'user-1' };
      mockSupabase.auth.getUser.mockResolvedValue({ data: { user: mockUser }, error: null });

      mockSupabase.from.mockReturnValueOnce({
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { missing_fields: ['latitude', 'longitude'] },
          error: null,
        }),
      }).mockReturnValueOnce({
        update: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({ error: null }),
      });

      await completeIncompleteCourse('course-1', {
        latitude: 40.7128,
        longitude: -74.0060,
        geocoded: true,
      });

      expect(mockSupabase.from).toHaveBeenCalledWith('course_contributions');
    });

    it('should throw error if user is not logged in', async () => {
      mockSupabase.auth.getUser.mockResolvedValue({ data: { user: null }, error: null });

      await expect(
        completeIncompleteCourse('course-1', {
          latitude: 40.7128,
          longitude: -74.0060,
        })
      ).rejects.toThrow('You must be logged in to complete a course');
    });
  });

  describe('geocodeAddress', () => {
    it('should geocode an address successfully', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: async () => [
          { lat: '40.7128', lon: '-74.0060' },
        ],
      });

      const result = await geocodeAddress('123 Main St', 'New York', 'US');

      expect(result).toEqual({ lat: 40.7128, lon: -74.0060 });
    });

    it('should return null if geocoding fails', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
      });

      const result = await geocodeAddress('Invalid Address');

      expect(result).toBeNull();
    });

    it('should return null if no results found', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        json: async () => [],
      });

      const result = await geocodeAddress('Invalid Address');

      expect(result).toBeNull();
    });
  });

  describe('getUserCompletions', () => {
    it('should return user completion statistics', async () => {
      const mockData = [
        { status: 'approved' },
        { status: 'approved' },
        { status: 'needs_verification' },
        { status: 'pending' },
      ];

      mockSupabase.from.mockReturnValue({
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockResolvedValue({ data: mockData, error: null }),
      });

      const result = await getUserCompletions('user-1');

      expect(result).toEqual({
        total: 4,
        verified: 2,
        pending: 2,
      });
    });
  });
});
