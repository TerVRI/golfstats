import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { OSMAutofill } from './osm-autofill';
import * as osmModule from '@/lib/openstreetmap';

// Mock the OSM module
vi.mock('@/lib/openstreetmap', () => ({
  searchOSMCourses: vi.fn(),
  convertOSMCourseToContribution: vi.fn(),
}));

describe('OSMAutofill', () => {
  const mockOnSelect = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should render search form', () => {
    render(<OSMAutofill onSelect={mockOnSelect} />);
    expect(screen.getByPlaceholderText('40.7128')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('-74.0060')).toBeInTheDocument();
    expect(screen.getByText(/Search OSM/i)).toBeInTheDocument();
  });

  it('should disable search button when coordinates are missing', async () => {
    render(<OSMAutofill onSelect={mockOnSelect} />);

    const searchButton = screen.getByText(/Search OSM/i);
    // Button should be disabled when coordinates are empty
    expect(searchButton).toBeDisabled();
  });

  it('should render with initial coordinates if provided', () => {
    render(<OSMAutofill onSelect={mockOnSelect} initialLat={36.5725} initialLon={-121.9486} />);
    
    const latInput = screen.getByPlaceholderText('40.7128') as HTMLInputElement;
    const lonInput = screen.getByPlaceholderText('-74.0060') as HTMLInputElement;
    
    expect(latInput.value).toBe('36.5725');
    expect(lonInput.value).toBe('-121.9486');
  });

  it('should search OSM when valid coordinates provided', async () => {
    const user = userEvent.setup();
    const mockCourses = [
      {
        id: 123,
        name: 'Test Course',
        lat: 36.5725,
        lon: -121.9486,
        type: 'way' as const,
        tags: { name: 'Test Course' },
      },
    ];

    vi.mocked(osmModule.searchOSMCourses).mockResolvedValueOnce({
      courses: mockCourses,
    });

    render(<OSMAutofill onSelect={mockOnSelect} />);

    const latInput = screen.getByPlaceholderText('40.7128');
    const lonInput = screen.getByPlaceholderText('-74.0060');
    const searchButton = screen.getByText(/Search OSM/i);

    await user.type(latInput, '36.5725');
    await user.type(lonInput, '-121.9486');
    await user.click(searchButton);

    await waitFor(() => {
      expect(osmModule.searchOSMCourses).toHaveBeenCalledWith(36.5725, -121.9486, 5000);
    });
  });

  it('should display found courses', async () => {
    const user = userEvent.setup();
    const mockCourses = [
      {
        id: 123,
        name: 'Pebble Beach Golf Links',
        lat: 36.5725,
        lon: -121.9486,
        type: 'way' as const,
        tags: {
          name: 'Pebble Beach Golf Links',
          'addr:city': 'Pebble Beach',
          'addr:state': 'CA',
        },
      },
    ];

    vi.mocked(osmModule.searchOSMCourses).mockResolvedValueOnce({
      courses: mockCourses,
    });

    render(<OSMAutofill onSelect={mockOnSelect} />);

    const latInput = screen.getByPlaceholderText('40.7128');
    const lonInput = screen.getByPlaceholderText('-74.0060');
    const searchButton = screen.getByText(/Search OSM/i);

    await user.type(latInput, '36.5725');
    await user.type(lonInput, '-121.9486');
    await user.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText('Pebble Beach Golf Links')).toBeInTheDocument();
    });
  });

  it('should call onSelect when course is selected', async () => {
    const user = userEvent.setup();
    const mockCourses = [
      {
        id: 123,
        name: 'Test Course',
        lat: 36.5725,
        lon: -121.9486,
        type: 'way' as const,
        tags: { name: 'Test Course' },
      },
    ];

    const mockContribution = {
      name: 'Test Course',
      latitude: 36.5725,
      longitude: -121.9486,
      source: 'osm' as const,
    };

    vi.mocked(osmModule.searchOSMCourses).mockResolvedValueOnce({
      courses: mockCourses,
    });
    vi.mocked(osmModule.convertOSMCourseToContribution).mockReturnValueOnce(mockContribution);

    render(<OSMAutofill onSelect={mockOnSelect} />);

    const latInput = screen.getByPlaceholderText('40.7128');
    const lonInput = screen.getByPlaceholderText('-74.0060');
    const searchButton = screen.getByText(/Search OSM/i);

    await user.type(latInput, '36.5725');
    await user.type(lonInput, '-121.9486');
    await user.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText('Test Course')).toBeInTheDocument();
    });

    const courseButton = screen.getByText('Test Course');
    await user.click(courseButton);

    expect(mockOnSelect).toHaveBeenCalledWith(mockContribution);
  });
});
