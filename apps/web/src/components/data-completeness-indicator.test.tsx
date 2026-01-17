import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { DataCompletenessIndicator } from './data-completeness-indicator';

describe('DataCompletenessIndicator', () => {
  it('should render completeness score', () => {
    render(<DataCompletenessIndicator score={75} />);
    expect(screen.getByText('75%')).toBeInTheDocument();
    expect(screen.getByText('Data Completeness')).toBeInTheDocument();
  });

  it('should show green color for high score (>= 80)', () => {
    render(<DataCompletenessIndicator score={85} />);
    const scoreElement = screen.getByText('85%');
    expect(scoreElement).toHaveClass('text-accent-green');
  });

  it('should show amber color for medium score (50-79)', () => {
    render(<DataCompletenessIndicator score={65} />);
    const scoreElement = screen.getByText('65%');
    expect(scoreElement).toHaveClass('text-accent-amber');
  });

  it('should show red color for low score (< 50)', () => {
    render(<DataCompletenessIndicator score={30} />);
    const scoreElement = screen.getByText('30%');
    expect(scoreElement).toHaveClass('text-red-500');
  });

  it('should display missing fields when showDetails is true', () => {
    const missingFields = ['hole_data', 'photos', 'tee_locations'];
    render(
      <DataCompletenessIndicator
        score={50}
        missingFields={missingFields}
        showDetails={true}
      />
    );
    expect(screen.getByText('Missing fields:')).toBeInTheDocument();
    expect(screen.getByText('hole data')).toBeInTheDocument();
    expect(screen.getByText('photos')).toBeInTheDocument();
  });

  it('should not display missing fields when showDetails is false', () => {
    const missingFields = ['hole_data'];
    render(
      <DataCompletenessIndicator
        score={50}
        missingFields={missingFields}
        showDetails={false}
      />
    );
    expect(screen.queryByText('Missing fields:')).not.toBeInTheDocument();
  });
});
