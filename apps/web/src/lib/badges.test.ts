import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchUserBadges, fetchBadgeDefinitions, calculateBadgeProgress, getUserBadgeSummary } from './badges';

// Mock Supabase client
const mockSupabase = {
  from: vi.fn(),
  rpc: vi.fn(),
};

vi.mock('@/lib/supabase/client', () => ({
  createClient: () => mockSupabase,
}));

describe('badges', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('fetchUserBadges', () => {
    it('should fetch user badges', async () => {
      const mockBadges = [
        {
          id: '1',
          user_id: 'user-1',
          badge_type: 'course_completer',
          badge_name: 'Course Completer',
          earned_at: '2025-01-21T00:00:00Z',
          progress: 100,
        },
      ];

      mockSupabase.from.mockReturnValue({
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({ data: mockBadges, error: null }),
      });

      const result = await fetchUserBadges('user-1');

      expect(result).toEqual(mockBadges);
      expect(mockSupabase.from).toHaveBeenCalledWith('user_badges');
    });

    it('should handle errors', async () => {
      mockSupabase.from.mockReturnValue({
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({ data: null, error: { message: 'Error' } }),
      });

      await expect(fetchUserBadges('user-1')).rejects.toBeDefined();
    });
  });

  describe('fetchBadgeDefinitions', () => {
    it('should fetch badge definitions', async () => {
      const mockDefinitions = [
        {
          badge_type: 'course_completer',
          badge_name: 'Course Completer',
          badge_description: 'Complete 1 incomplete course',
          badge_icon: '🏆',
          category: 'completion',
          requirement_type: 'count',
          requirement_value: 1,
          display_order: 1,
        },
      ];

      mockSupabase.from.mockReturnValue({
        select: vi.fn().mockReturnThis(),
        order: vi.fn().mockResolvedValue({ data: mockDefinitions, error: null }),
      });

      const result = await fetchBadgeDefinitions();

      expect(result).toEqual(mockDefinitions);
      expect(mockSupabase.from).toHaveBeenCalledWith('badge_definitions');
    });
  });

  describe('calculateBadgeProgress', () => {
    it('should calculate badge progress', async () => {
      const mockProgress = [
        {
          badge_type: 'course_completer',
          badge_name: 'Course Completer',
          earned: true,
          progress: 100,
        },
        {
          badge_type: 'location_master',
          badge_name: 'Location Master',
          earned: false,
          progress: 40,
        },
      ];

      mockSupabase.rpc.mockResolvedValue({ data: mockProgress, error: null });

      const result = await calculateBadgeProgress('user-1');

      expect(result).toEqual(mockProgress);
      expect(mockSupabase.rpc).toHaveBeenCalledWith('calculate_user_badges', {
        p_user_id: 'user-1',
      });
    });
  });

  describe('getUserBadgeSummary', () => {
    it('should return badge summary', async () => {
      const mockBadges = [
        {
          id: '1',
          badge_type: 'course_completer',
          earned_at: '2025-01-21T00:00:00Z',
        },
        {
          id: '2',
          badge_type: 'location_master',
          earned_at: '2025-01-20T00:00:00Z',
        },
      ];

      const mockDefinitions = [
        {
          badge_type: 'course_completer',
          category: 'completion',
        },
        {
          badge_type: 'location_master',
          category: 'completion',
        },
      ];

      mockSupabase.from
        .mockReturnValueOnce({
          select: vi.fn().mockReturnThis(),
          eq: vi.fn().mockReturnThis(),
          order: vi.fn().mockResolvedValue({ data: mockBadges, error: null }),
        })
        .mockReturnValueOnce({
          select: vi.fn().mockReturnThis(),
          order: vi.fn().mockResolvedValue({ data: mockDefinitions, error: null }),
        });

      const result = await getUserBadgeSummary('user-1');

      expect(result.total).toBe(2);
      expect(result.byCategory.completion).toBe(2);
      expect(result.recent).toHaveLength(2);
    });
  });
});
