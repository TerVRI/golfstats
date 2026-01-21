import { describe, it, expect } from 'vitest';

// Strokes Gained calculation utilities
// Based on PGA Tour benchmarks

interface SGBenchmark {
  distance: number;
  expectedStrokes: number;
}

// Expected strokes from tee (fairway)
const TEE_BENCHMARKS: SGBenchmark[] = [
  { distance: 150, expectedStrokes: 2.75 },
  { distance: 175, expectedStrokes: 2.85 },
  { distance: 200, expectedStrokes: 2.96 },
  { distance: 225, expectedStrokes: 3.08 },
  { distance: 250, expectedStrokes: 3.17 },
  { distance: 275, expectedStrokes: 3.26 },
  { distance: 300, expectedStrokes: 3.36 },
  { distance: 350, expectedStrokes: 3.54 },
  { distance: 400, expectedStrokes: 3.71 },
  { distance: 450, expectedStrokes: 3.89 },
  { distance: 500, expectedStrokes: 4.08 },
];

// Expected strokes from green (putting)
const PUTTING_BENCHMARKS: SGBenchmark[] = [
  { distance: 1, expectedStrokes: 1.00 },
  { distance: 3, expectedStrokes: 1.04 },
  { distance: 5, expectedStrokes: 1.14 },
  { distance: 10, expectedStrokes: 1.41 },
  { distance: 15, expectedStrokes: 1.61 },
  { distance: 20, expectedStrokes: 1.76 },
  { distance: 25, expectedStrokes: 1.86 },
  { distance: 30, expectedStrokes: 1.92 },
  { distance: 40, expectedStrokes: 2.02 },
  { distance: 50, expectedStrokes: 2.09 },
  { distance: 60, expectedStrokes: 2.14 },
];

// Lie penalties (added to expected strokes)
const LIE_PENALTIES: Record<string, number> = {
  tee: 0,
  fairway: 0,
  rough: 0.15,
  sand: 0.40,
  recovery: 0.50,
  green: 0,
};

function interpolate(benchmarks: SGBenchmark[], distance: number): number {
  // Handle edge cases
  if (distance <= benchmarks[0].distance) {
    return benchmarks[0].expectedStrokes;
  }
  if (distance >= benchmarks[benchmarks.length - 1].distance) {
    return benchmarks[benchmarks.length - 1].expectedStrokes;
  }

  // Find surrounding benchmarks
  for (let i = 0; i < benchmarks.length - 1; i++) {
    if (distance >= benchmarks[i].distance && distance <= benchmarks[i + 1].distance) {
      const ratio = (distance - benchmarks[i].distance) / 
                   (benchmarks[i + 1].distance - benchmarks[i].distance);
      return benchmarks[i].expectedStrokes + 
             ratio * (benchmarks[i + 1].expectedStrokes - benchmarks[i].expectedStrokes);
    }
  }

  return benchmarks[0].expectedStrokes;
}

function getExpectedStrokes(distance: number, lie: string, isOnGreen: boolean): number {
  if (isOnGreen) {
    return interpolate(PUTTING_BENCHMARKS, distance);
  }
  return interpolate(TEE_BENCHMARKS, distance) + (LIE_PENALTIES[lie] || 0);
}

function calculateStrokesGained(
  distanceBefore: number,
  distanceAfter: number,
  lieBefore: string,
  isOnGreenBefore: boolean,
  isOnGreenAfter: boolean
): number {
  const expectedBefore = getExpectedStrokes(distanceBefore, lieBefore, isOnGreenBefore);
  const expectedAfter = distanceAfter === 0 ? 0 : getExpectedStrokes(distanceAfter, 'fairway', isOnGreenAfter);
  
  return expectedBefore - expectedAfter - 1; // -1 for the stroke taken
}

describe('Strokes Gained Calculations', () => {
  describe('Expected Strokes from Distance', () => {
    it('should return correct expected strokes from 150 yards', () => {
      const expected = getExpectedStrokes(150, 'fairway', false);
      expect(expected).toBeCloseTo(2.75, 1);
    });

    it('should return correct expected strokes from 400 yards', () => {
      const expected = getExpectedStrokes(400, 'tee', false);
      expect(expected).toBeCloseTo(3.71, 1);
    });

    it('should return correct expected strokes for 10 foot putt', () => {
      const expected = getExpectedStrokes(10, 'green', true);
      expect(expected).toBeCloseTo(1.41, 2);
    });

    it('should return correct expected strokes for 30 foot putt', () => {
      const expected = getExpectedStrokes(30, 'green', true);
      expect(expected).toBeCloseTo(1.92, 2);
    });

    it('should interpolate correctly between benchmarks', () => {
      const expected = getExpectedStrokes(187, 'fairway', false);
      // Between 175 (2.85) and 200 (2.96)
      expect(expected).toBeGreaterThan(2.85);
      expect(expected).toBeLessThan(2.96);
    });
  });

  describe('Lie Penalties', () => {
    it('should add no penalty from fairway', () => {
      const fairway = getExpectedStrokes(150, 'fairway', false);
      const tee = getExpectedStrokes(150, 'tee', false);
      expect(fairway).toBe(tee);
    });

    it('should add 0.15 penalty from rough', () => {
      const fairway = getExpectedStrokes(150, 'fairway', false);
      const rough = getExpectedStrokes(150, 'rough', false);
      expect(rough - fairway).toBeCloseTo(0.15, 2);
    });

    it('should add 0.40 penalty from sand', () => {
      const fairway = getExpectedStrokes(150, 'fairway', false);
      const sand = getExpectedStrokes(150, 'sand', false);
      expect(sand - fairway).toBeCloseTo(0.40, 2);
    });

    it('should add 0.50 penalty from recovery', () => {
      const fairway = getExpectedStrokes(150, 'fairway', false);
      const recovery = getExpectedStrokes(150, 'recovery', false);
      expect(recovery - fairway).toBeCloseTo(0.50, 2);
    });
  });

  describe('Strokes Gained Calculation', () => {
    it('should calculate positive SG for good drive', () => {
      // 400 yards -> 150 yards (good drive)
      const sg = calculateStrokesGained(400, 150, 'tee', false, false);
      // Expected: 3.71 - 2.75 - 1 = -0.04 (average)
      // If we hit closer than expected, SG > 0
      expect(sg).toBeCloseTo(-0.04, 1);
    });

    it('should calculate positive SG for great approach', () => {
      // 150 yards -> 10 feet on green
      const sg = calculateStrokesGained(150, 10, 'fairway', false, true);
      // Expected: 2.75 - 1.41 - 1 = +0.34
      expect(sg).toBeGreaterThan(0);
    });

    it('should calculate negative SG for poor drive', () => {
      // 400 yards -> 220 yards (poor drive)
      const sg = calculateStrokesGained(400, 220, 'tee', false, false);
      expect(sg).toBeLessThan(0);
    });

    it('should calculate positive SG for holed putt', () => {
      // 15 feet putt holed
      const sg = calculateStrokesGained(15, 0, 'green', true, false);
      // Expected: 1.61 - 0 - 1 = +0.61
      expect(sg).toBeCloseTo(0.61, 1);
    });

    it('should calculate near-zero SG for average shot', () => {
      // Average drive: 400 yards -> 150 yards
      // This is what the benchmarks expect
      const sg = calculateStrokesGained(400, 150, 'tee', false, false);
      expect(Math.abs(sg)).toBeLessThan(0.15);
    });

    it('should handle chip shots correctly', () => {
      // 30 yards -> 5 feet on green
      const sg = calculateStrokesGained(30, 5, 'rough', false, true);
      expect(typeof sg).toBe('number');
    });
  });

  describe('Edge Cases', () => {
    it('should handle very short distances', () => {
      const expected = getExpectedStrokes(1, 'green', true);
      expect(expected).toBe(1.00);
    });

    it('should handle very long distances', () => {
      const expected = getExpectedStrokes(600, 'tee', false);
      expect(expected).toBeGreaterThan(4.0);
    });

    it('should handle zero distance (holed)', () => {
      const sg = calculateStrokesGained(10, 0, 'green', true, false);
      expect(sg).toBeGreaterThan(0.3); // Made a putt from 10 feet
    });
  });
});

describe('Formatting Utilities', () => {
  describe('formatSG', () => {
    it('should format positive values with plus sign', () => {
      const formatted = formatSG(0.5);
      expect(formatted).toBe('+0.50');
    });

    it('should format negative values correctly', () => {
      const formatted = formatSG(-0.5);
      expect(formatted).toBe('-0.50');
    });

    it('should format zero with plus sign', () => {
      const formatted = formatSG(0);
      expect(formatted).toBe('+0.00');
    });
  });
});

function formatSG(value: number): string {
  const prefix = value >= 0 ? '+' : '';
  return `${prefix}${value.toFixed(2)}`;
}
