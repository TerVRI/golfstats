import { describe, it, expect } from 'vitest';
import {
  cn,
  formatNumber,
  formatSG,
  formatDate,
  formatDateShort,
  calculateScoreToPar,
  getScoreColor,
  getSGColor,
  getSGBgColor,
} from './utils';

describe('cn (className utility)', () => {
  it('should merge class names', () => {
    expect(cn('class1', 'class2')).toContain('class1');
    expect(cn('class1', 'class2')).toContain('class2');
  });

  it('should handle conditional classes', () => {
    expect(cn('base', true && 'conditional')).toContain('conditional');
    expect(cn('base', false && 'conditional')).not.toContain('conditional');
  });

  it('should merge tailwind classes correctly', () => {
    // Should merge conflicting padding classes
    const result = cn('p-4', 'p-2');
    expect(result).toBe('p-2');
  });
});

describe('formatNumber', () => {
  it('should format with default decimals', () => {
    expect(formatNumber(3.14159)).toBe('3.1');
  });

  it('should format with custom decimals', () => {
    expect(formatNumber(3.14159, 2)).toBe('3.14');
    expect(formatNumber(3.14159, 0)).toBe('3');
  });

  it('should handle integers', () => {
    expect(formatNumber(42)).toBe('42.0');
  });
});

describe('formatSG', () => {
  it('should format positive values with plus sign', () => {
    expect(formatSG(0.5)).toBe('+0.50');
    expect(formatSG(1.234)).toBe('+1.23');
  });

  it('should format negative values correctly', () => {
    expect(formatSG(-0.5)).toBe('-0.50');
    expect(formatSG(-1.234)).toBe('-1.23');
  });

  it('should format zero with plus sign', () => {
    expect(formatSG(0)).toBe('+0.00');
  });
});

describe('formatDate', () => {
  it('should format date string correctly', () => {
    const result = formatDate('2024-06-15');
    expect(result).toContain('Jun');
    expect(result).toContain('15');
    expect(result).toContain('2024');
  });

  it('should format Date object correctly', () => {
    const date = new Date(2024, 5, 15); // June 15, 2024
    const result = formatDate(date);
    expect(result).toContain('Jun');
    expect(result).toContain('15');
  });
});

describe('formatDateShort', () => {
  it('should format date without year', () => {
    const result = formatDateShort('2024-06-15');
    expect(result).toContain('Jun');
    expect(result).toContain('15');
    expect(result).not.toContain('2024');
  });
});

describe('calculateScoreToPar', () => {
  it('should return "E" for even par', () => {
    expect(calculateScoreToPar(72, 72)).toBe('E');
  });

  it('should return positive number for over par', () => {
    expect(calculateScoreToPar(75, 72)).toBe('+3');
    expect(calculateScoreToPar(80, 72)).toBe('+8');
  });

  it('should return negative number for under par', () => {
    expect(calculateScoreToPar(70, 72)).toBe('-2');
    expect(calculateScoreToPar(65, 72)).toBe('-7');
  });
});

describe('getScoreColor', () => {
  it('should return amber for eagle or better', () => {
    expect(getScoreColor(70, 72)).toContain('amber');
  });

  it('should return green for birdie', () => {
    expect(getScoreColor(71, 72)).toContain('green');
  });

  it('should return default for par', () => {
    expect(getScoreColor(72, 72)).toContain('foreground');
  });

  it('should return light red for bogey', () => {
    expect(getScoreColor(73, 72)).toContain('red-light');
  });

  it('should return red for double or worse', () => {
    expect(getScoreColor(75, 72)).toContain('red');
    expect(getScoreColor(75, 72)).not.toContain('red-light');
  });
});

describe('getSGColor', () => {
  it('should return green for strongly positive', () => {
    expect(getSGColor(0.5)).toContain('green');
  });

  it('should return light green for slightly positive', () => {
    expect(getSGColor(0.2)).toContain('green');
  });

  it('should return light red for slightly negative', () => {
    expect(getSGColor(-0.2)).toContain('red');
  });

  it('should return red for strongly negative', () => {
    expect(getSGColor(-0.6)).toContain('red');
  });
});

describe('getSGBgColor', () => {
  it('should return green background for positive', () => {
    expect(getSGBgColor(0.5)).toContain('green');
  });

  it('should return red background for negative', () => {
    expect(getSGBgColor(-0.5)).toContain('red');
  });
});
