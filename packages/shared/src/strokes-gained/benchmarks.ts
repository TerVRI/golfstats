/**
 * PGA Tour Benchmark Data for Strokes Gained Calculations
 * 
 * These values represent the expected number of strokes to hole out
 * from various distances and lies, based on PGA Tour statistics.
 * 
 * Sources: PGA Tour ShotLink data, Mark Broadie's research
 */

// Expected strokes from the tee based on hole distance (yards)
// For tee shots, we use the average expected strokes from various distances
export const TEE_SHOT_BENCHMARKS: Record<number, number> = {
  100: 2.92,
  125: 2.99,
  150: 3.08,
  175: 3.18,
  200: 3.32,
  225: 3.45,
  250: 3.58,
  275: 3.71,
  300: 3.84,
  325: 3.97,
  350: 4.08,
  375: 4.17,
  400: 4.28,
  425: 4.41,
  450: 4.54,
  475: 4.69,
  500: 4.79,
  525: 4.96,
  550: 5.09,
  575: 5.24,
  600: 5.39,
};

// Expected strokes from fairway (yards to pin)
export const FAIRWAY_BENCHMARKS: Record<number, number> = {
  25: 2.40,
  50: 2.60,
  75: 2.72,
  100: 2.87,
  125: 2.95,
  150: 3.00,
  175: 3.08,
  200: 3.19,
  225: 3.32,
  250: 3.48,
  275: 3.65,
  300: 3.81,
};

// Expected strokes from rough (yards to pin)
export const ROUGH_BENCHMARKS: Record<number, number> = {
  25: 2.53,
  50: 2.73,
  75: 2.86,
  100: 2.98,
  125: 3.08,
  150: 3.17,
  175: 3.28,
  200: 3.42,
  225: 3.58,
  250: 3.75,
  275: 3.92,
  300: 4.08,
};

// Expected strokes from bunker (yards to pin)
export const BUNKER_BENCHMARKS: Record<number, number> = {
  10: 2.43,
  20: 2.53,
  30: 2.68,
  40: 2.83,
  50: 2.97,
  75: 3.15,
  100: 3.32,
  125: 3.52,
  150: 3.72,
};

// Expected strokes from recovery/trouble (yards to pin)
export const RECOVERY_BENCHMARKS: Record<number, number> = {
  25: 2.77,
  50: 2.96,
  75: 3.12,
  100: 3.24,
  125: 3.38,
  150: 3.51,
  175: 3.66,
  200: 3.82,
};

// Expected putts from various distances (feet)
export const PUTTING_BENCHMARKS: Record<number, number> = {
  1: 1.001,
  2: 1.009,
  3: 1.044,
  4: 1.115,
  5: 1.211,
  6: 1.299,
  7: 1.373,
  8: 1.438,
  9: 1.495,
  10: 1.546,
  12: 1.635,
  14: 1.710,
  16: 1.774,
  18: 1.829,
  20: 1.877,
  25: 1.970,
  30: 2.040,
  35: 2.095,
  40: 2.140,
  45: 2.179,
  50: 2.213,
  60: 2.267,
  70: 2.310,
  80: 2.346,
  90: 2.376,
};

// Expected strokes when on green but far from hole (for GIR approach calculation)
export const ON_GREEN_BENCHMARKS: Record<number, number> = {
  5: 1.26,
  10: 1.55,
  15: 1.72,
  20: 1.88,
  25: 1.97,
  30: 2.04,
  40: 2.14,
  50: 2.22,
  60: 2.27,
};

/**
 * Interpolate between benchmark values
 */
export function interpolate(
  benchmarks: Record<number, number>,
  distance: number
): number {
  const distances = Object.keys(benchmarks)
    .map(Number)
    .sort((a, b) => a - b);
  
  // Handle edge cases
  if (distance <= distances[0]) return benchmarks[distances[0]];
  if (distance >= distances[distances.length - 1]) {
    return benchmarks[distances[distances.length - 1]];
  }
  
  // Find surrounding values and interpolate
  let lower = distances[0];
  let upper = distances[distances.length - 1];
  
  for (let i = 0; i < distances.length - 1; i++) {
    if (distances[i] <= distance && distances[i + 1] >= distance) {
      lower = distances[i];
      upper = distances[i + 1];
      break;
    }
  }
  
  const ratio = (distance - lower) / (upper - lower);
  return benchmarks[lower] + ratio * (benchmarks[upper] - benchmarks[lower]);
}

/**
 * Get expected strokes from fairway at given distance
 */
export function getExpectedFromFairway(yardsToPin: number): number {
  return interpolate(FAIRWAY_BENCHMARKS, yardsToPin);
}

/**
 * Get expected strokes from rough at given distance
 */
export function getExpectedFromRough(yardsToPin: number): number {
  return interpolate(ROUGH_BENCHMARKS, yardsToPin);
}

/**
 * Get expected strokes from bunker at given distance
 */
export function getExpectedFromBunker(yardsToPin: number): number {
  return interpolate(BUNKER_BENCHMARKS, yardsToPin);
}

/**
 * Get expected strokes from recovery position
 */
export function getExpectedFromRecovery(yardsToPin: number): number {
  return interpolate(RECOVERY_BENCHMARKS, yardsToPin);
}

/**
 * Get expected putts from given distance in feet
 */
export function getExpectedPutts(feetToHole: number): number {
  return interpolate(PUTTING_BENCHMARKS, feetToHole);
}

/**
 * Get expected strokes when on green at given distance
 */
export function getExpectedOnGreen(feetToHole: number): number {
  return interpolate(ON_GREEN_BENCHMARKS, feetToHole);
}

/**
 * Get expected strokes from tee based on hole distance
 */
export function getExpectedFromTee(holeDistance: number): number {
  return interpolate(TEE_SHOT_BENCHMARKS, holeDistance);
}

