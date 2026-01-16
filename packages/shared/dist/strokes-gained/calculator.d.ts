/**
 * Strokes Gained Calculator
 *
 * Implements the Strokes Gained methodology to analyze golf performance.
 * Based on Mark Broadie's work and PGA Tour ShotLink data.
 *
 * Formula: SG = Expected Strokes (start) - Expected Strokes (end) - 1
 *
 * A positive SG means the player gained strokes vs the benchmark.
 * A negative SG means the player lost strokes vs the benchmark.
 */
import type { HoleEntryData } from "../types/golf";
export interface StrokesGainedResult {
    sg_off_tee: number;
    sg_approach: number;
    sg_around_green: number;
    sg_putting: number;
    sg_total: number;
}
/**
 * Calculate Strokes Gained for a single hole
 */
export declare function calculateHoleStrokesGained(holeData: HoleEntryData, holeYardage?: number): StrokesGainedResult;
/**
 * Calculate aggregate Strokes Gained for a full round
 */
export declare function calculateRoundStrokesGained(holes: HoleEntryData[], holeYardages?: number[]): StrokesGainedResult;
/**
 * Get per-round average Strokes Gained from multiple rounds
 */
export declare function calculateAverageStrokesGained(roundsData: StrokesGainedResult[]): StrokesGainedResult;
/**
 * Identify the weakest area of the game based on Strokes Gained
 */
export declare function identifyWeakestArea(sg: StrokesGainedResult): {
    area: string;
    value: number;
    recommendation: string;
};
/**
 * Identify the strongest area of the game based on Strokes Gained
 */
export declare function identifyStrongestArea(sg: StrokesGainedResult): {
    area: string;
    value: number;
};
//# sourceMappingURL=calculator.d.ts.map