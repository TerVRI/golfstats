import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { CourseDiscussions } from './course-discussions';
import { createClient } from '@/lib/supabase/client';

// Mock Supabase client
vi.mock('@/lib/supabase/client', () => ({
  createClient: vi.fn(),
}));

// Mock useUser hook
vi.mock('@/hooks/useUser', () => ({
  useUser: () => ({
    user: { id: 'test-user-id', email: 'test@example.com' },
    loading: false,
  }),
}));

describe('CourseDiscussions', () => {
  const mockSupabase = {
    from: vi.fn(),
  };

  beforeEach(() => {
    vi.clearAllMocks();
    (createClient as any).mockReturnValue(mockSupabase);
  });

  it('should render discussions component', () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: [],
      error: null,
    });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    expect(screen.getByText('Discussions')).toBeInTheDocument();
  });

  it('should display "New Question" button when user is logged in', () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: [],
      error: null,
    });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    expect(screen.getByText('New Question')).toBeInTheDocument();
  });

  it('should show empty state when no discussions exist', async () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: [],
      error: null,
    });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    await waitFor(() => {
      expect(screen.getByText('No discussions yet')).toBeInTheDocument();
      expect(screen.getByText('Be the first to ask a question!')).toBeInTheDocument();
    });
  });

  it('should display existing discussions', async () => {
    const mockDiscussions = [
      {
        id: 'discussion-1',
        title: 'Test Discussion',
        content: 'This is a test discussion',
        user_id: 'user-1',
        upvotes: 5,
        created_at: '2024-01-01T00:00:00Z',
        profiles: { full_name: 'Test User', avatar_url: null },
      },
    ];

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: mockDiscussions,
      error: null,
    });

    // Mock replies fetch
    const mockRepliesSelect = vi.fn().mockReturnThis();
    const mockRepliesEq = vi.fn().mockReturnThis();
    const mockRepliesOrder = vi.fn().mockResolvedValue({
      data: [],
      error: null,
    });

    mockSupabase.from.mockImplementation((table) => {
      if (table === 'discussion_replies') {
        return {
          select: mockRepliesSelect,
          eq: mockRepliesEq,
          order: mockRepliesOrder,
        };
      }
      return {
        select: mockSelect,
        eq: mockEq,
        order: mockOrder,
      };
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    await waitFor(() => {
      expect(screen.getByText('Test Discussion')).toBeInTheDocument();
    });
    
    // Use getAllByText for content that might appear multiple times
    const contentElements = screen.getAllByText('This is a test discussion');
    expect(contentElements.length).toBeGreaterThan(0);
  });

  it('should show new discussion form when "New Question" button is clicked', async () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: [],
      error: null,
    });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
      insert: vi.fn().mockResolvedValue({ error: null }),
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    const newQuestionButton = screen.getByText('New Question');
    fireEvent.click(newQuestionButton);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('Question title')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Ask a question about this course...')).toBeInTheDocument();
    });
  });

  it('should create a new discussion when form is submitted', async () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn()
      .mockResolvedValueOnce({ data: [], error: null })
      .mockResolvedValueOnce({ data: [], error: null });

    const mockInsert = vi.fn().mockResolvedValue({ error: null });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
      insert: mockInsert,
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    // Open form
    const newQuestionButton = screen.getByText('New Question');
    fireEvent.click(newQuestionButton);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('Question title')).toBeInTheDocument();
    });

    // Fill form
    const titleInput = screen.getByPlaceholderText('Question title');
    const contentInput = screen.getByPlaceholderText('Ask a question about this course...');
    
    fireEvent.change(titleInput, { target: { value: 'New Question Title' } });
    fireEvent.change(contentInput, { target: { value: 'New question content' } });

    // Submit
    const postButton = screen.getByText('Post');
    fireEvent.click(postButton);

    await waitFor(() => {
      expect(mockInsert).toHaveBeenCalledWith({
        course_id: 'test-course-id',
        user_id: 'test-user-id',
        title: 'New Question Title',
        content: 'New question content',
      });
    });
  });

  it('should not create discussion if title or content is empty', async () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: [],
      error: null,
    });

    const mockInsert = vi.fn().mockResolvedValue({ error: null });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
      insert: mockInsert,
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    // Open form
    const newQuestionButton = screen.getByText('New Question');
    fireEvent.click(newQuestionButton);

    await waitFor(() => {
      expect(screen.getByPlaceholderText('Question title')).toBeInTheDocument();
    });

    // Try to submit without filling
    const postButton = screen.getByText('Post');
    fireEvent.click(postButton);

    // Should not call insert
    expect(mockInsert).not.toHaveBeenCalled();
  });

  it('should display replies for discussions', async () => {
    const mockDiscussions = [
      {
        id: 'discussion-1',
        title: 'Test Discussion',
        content: 'This is a test discussion',
        user_id: 'user-1',
        upvotes: 5,
        created_at: '2024-01-01T00:00:00Z',
        profiles: { full_name: 'Test User', avatar_url: null },
      },
    ];

    const mockReplies = [
      {
        id: 'reply-1',
        content: 'This is a reply',
        user_id: 'user-2',
        upvotes: 2,
        is_solution: false,
        created_at: '2024-01-01T01:00:00Z',
        profiles: { full_name: 'Reply User', avatar_url: null },
      },
    ];

    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: mockDiscussions,
      error: null,
    });

    // Mock replies fetch
    const mockRepliesSelect = vi.fn().mockReturnThis();
    const mockRepliesEq = vi.fn().mockReturnThis();
    const mockRepliesOrder = vi.fn().mockResolvedValue({
      data: mockReplies,
      error: null,
    });

    mockSupabase.from.mockImplementation((table) => {
      if (table === 'discussion_replies') {
        return {
          select: mockRepliesSelect,
          eq: mockRepliesEq,
          order: mockRepliesOrder,
        };
      }
      return {
        select: mockSelect,
        eq: mockEq,
        order: mockOrder,
      };
    });

    render(<CourseDiscussions courseId="test-course-id" />);
    
    await waitFor(() => {
      expect(screen.getByText('This is a reply')).toBeInTheDocument();
      expect(screen.getByText('Reply User')).toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('should handle errors when fetching discussions', async () => {
    const mockSelect = vi.fn().mockReturnThis();
    const mockEq = vi.fn().mockReturnThis();
    const mockOrder = vi.fn().mockResolvedValue({
      data: null,
      error: { message: 'Failed to fetch' },
    });

    mockSupabase.from.mockReturnValue({
      select: mockSelect,
      eq: mockEq,
      order: mockOrder,
    });

    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    render(<CourseDiscussions courseId="test-course-id" />);
    
    await waitFor(() => {
      expect(consoleSpy).toHaveBeenCalled();
    });

    consoleSpy.mockRestore();
  });
});
