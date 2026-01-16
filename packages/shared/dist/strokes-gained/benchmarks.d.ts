/**
 * PGA Tour Benchmark Data for Strokes Gained Calculations
 *
 * These values represent the expected number of strokes to hole out
 * from various distances and lies, based on PGA Tour statistics.
 *
 * Sources: PGA Tour ShotLink data, Mark Broadie's research
 */
export declare const TEE_SHOT_BENCHMARKS: Record<number, number>;
export declare const FAIRWAY_BENCHMARKS: Record<number, number>;
export declare const ROUGH_BENCHMARKS: Record<number, number>;
export declare const BUNKER_BENCHMARKS: Record<number, number>;
export declare const RECOVERY_BENCHMARKS: Record<number, number>;
export declare const PUTTING_BENCHMARKS: Record<number, number>;
export declare const ON_GREEN_BENCHMARKS: Record<number, number>;
/**
 * Interpolate between benchmark values
 */
export declare function interpolate(benchmarks: Record<number, number>, distance: number): number;
/**
 * Get expected strokes from fairway at given distance
 */
export declare function getExpectedFromFairway(yardsToPin: number): number;
/**
 * Get expected strokes from rough at given distance
 */
export declare function getExpectedFromRough(yardsToPin: number): number;
/**
 * Get expected strokes from bunker at given distance
 */
export declare function getExpectedFromBunker(yardsToPin: number): number;
/**
 * Get expected strokes from recovery position
 */
export declare function getExpectedFromRecovery(yardsToPin: number): number;
/**
 * Get expected putts from given distance in feet
 */
export declare function getExpectedPutts(feetToHole: number): number;
/**
 * Get expected strokes when on green at given distance
 */
export declare function getExpectedOnGreen(feetToHole: number): number;
/**
 * Get expected strokes from tee based on hole distance
 */
export declare function getExpectedFromTee(holeDistance: number): number;
//# sourceMappingURL=benchmarks.d.ts.map