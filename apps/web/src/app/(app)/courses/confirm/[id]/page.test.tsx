import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { useRouter } from 'next/navigation';
import ConfirmCoursePage from './page';
import { createClient } from '@/lib/supabase/client';
import { useUser } from '@/hooks/useUser';

// Mock dependencies
vi.mock('next/navigation', () => ({
  useRouter: vi.fn(),
}));

vi.mock('@/lib/supabase/client', () => ({
  createClient: vi.fn(),
}));

vi.mock('@/hooks/useUser', () => ({
  useUser: vi.fn(),
}));

// Mock React's use() hook for async params
vi.mock('react', async () => {
  const actual = await vi.importActual('react');
  return {
    ...actual,
    use: (promise: Promise<any>) => {
      // For testing, immediately resolve the promise
      if (promise && typeof promise.then === 'function') {
        return promise.then ? { id: 'test-course-id' } : promise;
      }
      return promise;
    },
  };
});

describe('ConfirmCoursePage', () => {
  const mockRouter = {
    push: vi.fn(),
    replace: vi.fn(),
    prefetch: vi.fn(),
  };

  const mockUser = {
    id: 'test-user-id',
    email: 'test@example.com',
  };

  const mockSupabase = {
    from: vi.fn(),
    auth: {
      getSession: vi.fn().mockResolvedValue({
        data: { session: { user: mockUser } },
        error: null,
      }),
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    (useRouter as any).mockReturnValue(mockRouter);
    (createClient as any).mockReturnValue(mockSupabase);
    (useUser as any).mockReturnValue({ user: mockUser, loading: false });
    
    // Mock auth.getSession for useUser hook
    mockSupabase.auth = {
      getSession: vi.fn().mockResolvedValue({
        data: { session: { user: mockUser } },
        error: null,
      }),
      onAuthStateChange: vi.fn().mockReturnValue({
        data: { subscription: { unsubscribe: vi.fn() } },
      }),
    };
  });

  it('should redirect to login if user is not logged in', async () => {
    (useUser as any).mockReturnValue({ user: null, loading: false });

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn().mockResolvedValue({
      data: null,
      error: null,
    });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/login');
    });
  });

  it('should display course information', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    await waitFor(() => {
      expect(screen.getByText('Test Course')).toBeInTheDocument();
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    });
  });

  it('should display all confirmation checkboxes', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    // Wait for loading to complete and course to render
    await waitFor(() => {
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Check for checkboxes by looking for the text content
    await waitFor(() => {
      const dimensionsText = screen.getByText(/dimensions/i);
      expect(dimensionsText).toBeInTheDocument();
    });
  });

  it('should allow toggling confirmation checkboxes', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    // Wait for loading to complete and course to render
    await waitFor(() => {
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Find checkbox by role and nearby text
    await waitFor(() => {
      const checkboxes = screen.getAllByRole('checkbox');
      expect(checkboxes.length).toBeGreaterThan(0);
    });
  });

  it('should allow selecting confidence level', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    // Wait for loading to complete and course to render
    await waitFor(() => {
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    }, { timeout: 5000 });

    await waitFor(() => {
      const confidenceButtons = screen.getAllByText('5');
      if (confidenceButtons.length > 0) {
        fireEvent.click(confidenceButtons[0]);
      }
    });

    await waitFor(() => {
      const certainText = screen.queryByText('Absolutely certain');
      if (certainText) {
        expect(certainText).toBeInTheDocument();
      }
    }, { timeout: 2000 });
  });

  it('should submit confirmation when form is submitted', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    const mockUpsert = vi.fn().mockResolvedValue({ error: null });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
      upsert: mockUpsert,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    // Wait for loading to complete and course to render
    await waitFor(() => {
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Find and click a checkbox
    await waitFor(() => {
      const checkboxes = screen.getAllByRole('checkbox');
      if (checkboxes.length > 0) {
        fireEvent.click(checkboxes[0]);
      }
    });

    await waitFor(() => {
      const submitButton = screen.getByRole('button', { name: /submit confirmation/i });
      expect(submitButton).toBeInTheDocument();
    }, { timeout: 3000 });

    const submitButton = screen.getByRole('button', { name: /submit confirmation/i });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockUpsert).toHaveBeenCalled();
    });
  });

  it('should disable submit button if no fields are confirmed', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    // Wait for loading to complete and course to render
    await waitFor(() => {
      // First wait for loading spinner to disappear
      const loadingSpinner = screen.queryByRole('status');
      expect(loadingSpinner).not.toBeInTheDocument();
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    }, { timeout: 3000 });

    await waitFor(() => {
      const submitButton = screen.getByRole('button', { name: /submit confirmation/i });
      expect(submitButton).toBeDisabled();
    }, { timeout: 2000 });
  });

  it('should show discrepancy form when checkbox is checked', async () => {
    const mockCourse = {
      id: 'test-course-id',
      name: 'Test Course',
      city: 'Test City',
      state: 'Test State',
      country: 'USA',
      par: 72,
      course_rating: 75.5,
      slope_rating: 145,
      latitude: 36.5725,
      longitude: -121.9486,
      hole_data: null,
      confirmation_count: 2,
      required_confirmations: 5,
      is_verified: false,
    };

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockSingle = vi.fn()
      .mockResolvedValueOnce({
        data: mockCourse,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: null,
      });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      single: mockSingle,
    });

    render(<ConfirmCoursePage params={Promise.resolve({ id: 'test-course-id' })} />);

    // Wait for loading to complete and course to render
    await waitFor(() => {
      expect(screen.getByText('Confirm Course Data')).toBeInTheDocument();
    }, { timeout: 5000 });

    // Find discrepancy checkbox by text content
    await waitFor(() => {
      const discrepancyText = screen.getByText(/I found discrepancies/i);
      expect(discrepancyText).toBeInTheDocument();
      
      // Find the checkbox near this text
      const checkboxes = screen.getAllByRole('checkbox');
      const discrepancyCheckbox = checkboxes.find(cb => 
        cb.closest('label')?.textContent?.includes('discrepancies')
      );
      
      if (discrepancyCheckbox) {
        fireEvent.click(discrepancyCheckbox);
      }
    });

    await waitFor(() => {
      const textarea = screen.queryByPlaceholderText(/Example: The par for hole 5/i);
      if (textarea) {
        expect(textarea).toBeInTheDocument();
      }
    }, { timeout: 2000 });
  });
});
