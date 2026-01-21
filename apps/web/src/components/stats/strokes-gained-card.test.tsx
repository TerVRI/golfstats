import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { StrokesGainedCard } from './strokes-gained-card';

describe('StrokesGainedCard', () => {
  it('should render with positive value', () => {
    render(
      <StrokesGainedCard
        category="total"
        value={0.5}
        label="Total SG"
      />
    );

    expect(screen.getByText('Total SG')).toBeInTheDocument();
    expect(screen.getByText('+0.50')).toBeInTheDocument();
  });

  it('should render with negative value', () => {
    render(
      <StrokesGainedCard
        category="total"
        value={-0.5}
        label="Total SG"
      />
    );

    expect(screen.getByText('-0.50')).toBeInTheDocument();
  });

  it('should render with zero value', () => {
    render(
      <StrokesGainedCard
        category="total"
        value={0}
        label="Total SG"
      />
    );

    expect(screen.getByText('+0.00')).toBeInTheDocument();
  });

  it('should show trend indicator when provided', () => {
    render(
      <StrokesGainedCard
        category="total"
        value={0.5}
        label="Total SG"
        showTrend
        trend={0.2}
      />
    );

    // Should show positive trend
    expect(screen.getByText(/\+0\.20/)).toBeInTheDocument();
  });

  it('should show negative trend indicator', () => {
    render(
      <StrokesGainedCard
        category="total"
        value={0.5}
        label="Total SG"
        showTrend
        trend={-0.2}
      />
    );

    // Should show negative trend
    expect(screen.getByText(/-0\.20/)).toBeInTheDocument();
  });

  describe('Category styling', () => {
    it('should render off_tee category', () => {
      render(
        <StrokesGainedCard
          category="off_tee"
          value={0.3}
          label="SG: Off the Tee"
        />
      );

      expect(screen.getByText('SG: Off the Tee')).toBeInTheDocument();
    });

    it('should render approach category', () => {
      render(
        <StrokesGainedCard
          category="approach"
          value={0.2}
          label="SG: Approach"
        />
      );

      expect(screen.getByText('SG: Approach')).toBeInTheDocument();
    });

    it('should render around_green category', () => {
      render(
        <StrokesGainedCard
          category="around_green"
          value={-0.1}
          label="SG: Around Green"
        />
      );

      expect(screen.getByText('SG: Around Green')).toBeInTheDocument();
    });

    it('should render putting category', () => {
      render(
        <StrokesGainedCard
          category="putting"
          value={0.1}
          label="SG: Putting"
        />
      );

      expect(screen.getByText('SG: Putting')).toBeInTheDocument();
    });
  });

  describe('Color coding', () => {
    it('should use green color for positive values', () => {
      const { container } = render(
        <StrokesGainedCard
          category="total"
          value={0.5}
          label="Total SG"
        />
      );

      // Check that there's an element with green styling
      const valueElement = screen.getByText('+0.50');
      expect(valueElement.className).toMatch(/green/i);
    });

    it('should use red color for negative values', () => {
      const { container } = render(
        <StrokesGainedCard
          category="total"
          value={-0.5}
          label="Total SG"
        />
      );

      const valueElement = screen.getByText('-0.50');
      expect(valueElement.className).toMatch(/red/i);
    });
  });
});
