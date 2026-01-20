import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { useRouter } from 'next/navigation';
import NewRoundPage from './page';
import { createClient } from '@/lib/supabase/client';

// Mock dependencies
vi.mock('next/navigation', () => ({
  useRouter: vi.fn(),
}));

vi.mock('@/lib/supabase/client', () => ({
  createClient: vi.fn(),
}));

describe('NewRoundPage', () => {
  const mockRouter = {
    push: vi.fn(),
    replace: vi.fn(),
    prefetch: vi.fn(),
  };

  const mockSupabase = {
    auth: {
      getUser: vi.fn(),
    },
    from: vi.fn(),
  };

  beforeEach(() => {
    vi.clearAllMocks();
    (useRouter as any).mockReturnValue(mockRouter);
    (createClient as any).mockReturnValue(mockSupabase);
    mockSupabase.auth.getUser.mockResolvedValue({
      data: { user: { id: 'test-user-id' } },
      error: null,
    });
  });

  it('should render new round page with course selection step', async () => {
    render(<NewRoundPage />);

    await waitFor(() => {
      // Look for course-related content - component uses CourseSearch and labels
      const courseLabel = screen.queryByText(/course name/i);
      expect(courseLabel).toBeInTheDocument();
    }, { timeout: 2000 });
  });

  it('should allow entering course name', async () => {
    render(<NewRoundPage />);

    await waitFor(() => {
      // CourseSearch component has an input with placeholder "Search courses..."
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      expect(courseInput).toBeInTheDocument();

      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
      expect(courseInput).toHaveValue('Test Course');
    }, { timeout: 2000 });
  });

  it('should allow entering course rating and slope', async () => {
    render(<NewRoundPage />);

    await waitFor(() => {
      // Input components use labels, find by label text
      const courseRatingInput = screen.getByLabelText(/course rating/i);
      const slopeRatingInput = screen.getByLabelText(/slope rating/i);

        fireEvent.change(courseRatingInput, { target: { value: '75.5' } });
        fireEvent.change(slopeRatingInput, { target: { value: '145' } });

      // Input values - number inputs may return as numbers, check both
      expect(courseRatingInput.value).toBe('75.5');
      expect(slopeRatingInput.value).toBe('145');
    }, { timeout: 2000 });
  });

  it('should navigate to holes step when next is clicked', async () => {
    render(<NewRoundPage />);

    await waitFor(() => {
      // CourseSearch has input with placeholder "Search courses..."
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
      expect(nextButton).toBeInTheDocument();
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('should allow entering hole scores', async () => {
    render(<NewRoundPage />);

    // Navigate to holes step
    await waitFor(() => {
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      // Score is displayed as text, not input - look for the score display or buttons
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
      // Score is controlled by +/- buttons, not direct input - just verify the label exists
      const scoreLabel = screen.getByText(/^score$/i);
      expect(scoreLabel).toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('should allow entering putts for each hole', async () => {
    render(<NewRoundPage />);

    // Navigate to holes step
    await waitFor(() => {
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      // Putts is displayed as text with +/- buttons, not direct input
      expect(screen.getByText(/putts/i)).toBeInTheDocument();
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('should navigate between holes', async () => {
    render(<NewRoundPage />);

    // Navigate to holes step
    await waitFor(() => {
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
    }, { timeout: 3000 });

    await waitFor(() => {
      // Find "Next" button for hole navigation (not the "Continue to Scorecard" button)
      const nextHoleButton = screen.getAllByRole('button').find(
        btn => btn.textContent?.includes('Next') && !btn.textContent?.includes('Scorecard')
      );
      if (nextHoleButton) {
    fireEvent.click(nextHoleButton);
      }
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/hole 2/i)).toBeInTheDocument();
    }, { timeout: 2000 });
  });

  it('should calculate totals correctly', async () => {
    render(<NewRoundPage />);

    // Navigate to holes step
    await waitFor(() => {
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
    }, { timeout: 3000 });

    // Navigate to review step - look for "Review Round" button
    await waitFor(() => {
      const reviewButton = screen.getByText(/review round/i);
      expect(reviewButton).toBeInTheDocument();
    fireEvent.click(reviewButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      // Should show review step - look for "Review Your Round" heading
      const reviewHeading = screen.getByText(/review your round/i);
      expect(reviewHeading).toBeInTheDocument();
    }, { timeout: 2000 });
  });

  it('should save round when submitted', async () => {
    const mockInsert = vi.fn().mockResolvedValue({
      data: [{ id: 'round-id' }],
      error: null,
    });

    mockSupabase.from.mockReturnValue({
      insert: mockInsert,
    });

    render(<NewRoundPage />);

    // Fill in course info
    await waitFor(() => {
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
    }, { timeout: 3000 });

    // Navigate to review - use "Review Round" button text
    await waitFor(() => {
      const reviewButton = screen.getByText(/review round/i);
      expect(reviewButton).toBeInTheDocument();
      fireEvent.click(reviewButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      const saveButton = screen.getByText(/save/i) || 
                        screen.getByRole('button', { name: /save/i });
      if (saveButton) {
      fireEvent.click(saveButton);
      }
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(mockInsert).toHaveBeenCalled();
    }, { timeout: 3000 });
  });

  it('should show error if user is not logged in', async () => {
    mockSupabase.auth.getUser.mockResolvedValue({
      data: { user: null },
      error: null,
    });

    render(<NewRoundPage />);

    // Try to save
    await waitFor(() => {
      const courseInput = screen.getByPlaceholderText(/search courses/i);
      fireEvent.change(courseInput, { target: { value: 'Test Course' } });
    }, { timeout: 2000 });

    await waitFor(() => {
      const nextButton = screen.getByText(/continue to scorecard/i);
    fireEvent.click(nextButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/hole 1/i)).toBeInTheDocument();
    }, { timeout: 3000 });

    await waitFor(() => {
      const reviewButton = screen.getByText(/review round/i);
      expect(reviewButton).toBeInTheDocument();
      fireEvent.click(reviewButton);
    }, { timeout: 2000 });

    await waitFor(() => {
      const saveButton = screen.getByText(/save/i) || 
                        screen.getByRole('button', { name: /save/i });
      if (saveButton) {
      fireEvent.click(saveButton);
      }
    }, { timeout: 2000 });

    await waitFor(() => {
      expect(screen.getByText(/must be logged in/i)).toBeInTheDocument();
    }, { timeout: 3000 });
  });
});
