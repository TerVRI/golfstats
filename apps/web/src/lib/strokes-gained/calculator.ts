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

import {
  getExpectedFromFairway,
  getExpectedFromRough,
  getExpectedFromBunker,
  getExpectedPutts,
  getExpectedOnGreen,
  getExpectedFromTee,
} from "./benchmarks";
import type { HoleEntryData, ApproachResult } from "@/types/golf";

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
export function calculateHoleStrokesGained(
  holeData: HoleEntryData,
  holeYardage: number = 400 // Default hole length if not provided
): StrokesGainedResult {
  const { par, score, putts, fairway_hit, gir, approach_distance, approach_result, first_putt_distance } = holeData;
  
  let sg_off_tee = 0;
  let sg_approach = 0;
  let sg_around_green = 0;
  let sg_putting = 0;

  // Estimate distances based on typical scenarios if not provided
  const estimatedApproachDistance = approach_distance || estimateApproachDistance(par, holeYardage);
  const estimatedFirstPuttDistance = first_putt_distance || estimateFirstPuttDistance(gir, score, par, putts);

  // === PUTTING ===
  // SG Putting = Expected putts from first putt distance - actual putts
  if (putts > 0 && estimatedFirstPuttDistance > 0) {
    const expectedPutts = getExpectedPutts(estimatedFirstPuttDistance);
    sg_putting = expectedPutts - putts;
  }

  // === OFF THE TEE (Par 4s and 5s only) ===
  if (par >= 4) {
    // Calculate based on where the tee shot ended up
    const expectedFromTee = getExpectedFromTee(holeYardage);
    
    if (fairway_hit === true) {
      // Hit fairway - compare to expected from fairway position
      const expectedFromFairway = getExpectedFromFairway(estimatedApproachDistance);
      sg_off_tee = expectedFromTee - expectedFromFairway - 1;
    } else if (fairway_hit === false) {
      // Missed fairway - compare to expected from rough
      const expectedFromRough = getExpectedFromRough(estimatedApproachDistance);
      sg_off_tee = expectedFromTee - expectedFromRough - 1;
    } else {
      // Unknown - use average
      const avgExpected = (getExpectedFromFairway(estimatedApproachDistance) + 
                          getExpectedFromRough(estimatedApproachDistance)) / 2;
      sg_off_tee = expectedFromTee - avgExpected - 1;
    }
  }

  // === APPROACH ===
  if (estimatedApproachDistance > 0) {
    const startingExpected = fairway_hit 
      ? getExpectedFromFairway(estimatedApproachDistance)
      : getExpectedFromRough(estimatedApproachDistance);
    
    if (gir) {
      // Hit the green - compare to expected from green position
      const expectedOnGreen = getExpectedOnGreen(estimatedFirstPuttDistance);
      sg_approach = startingExpected - expectedOnGreen - 1;
    } else {
      // Missed green - calculate based on result
      const endingExpected = getExpectedFromMissedGreen(approach_result, estimatedApproachDistance);
      sg_approach = startingExpected - endingExpected - 1;
    }
  }

  // === AROUND THE GREEN ===
  // Only applies if we missed the green
  if (!gir) {
    const shotsAroundGreen = score - putts - (par >= 4 ? 2 : 1);
    if (shotsAroundGreen > 0) {
      // Estimate the chip/pitch shot performance
      const expectedFromAroundGreen = getExpectedFromChipPosition(approach_result);
      const actualShotsToGreen = shotsAroundGreen;
      const expectedOnGreen = getExpectedOnGreen(estimatedFirstPuttDistance);
      
      sg_around_green = expectedFromAroundGreen - expectedOnGreen - actualShotsToGreen;
    }
  }

  // Calculate total
  const sg_total = sg_off_tee + sg_approach + sg_around_green + sg_putting;

  return {
    sg_off_tee: roundToHundredth(sg_off_tee),
    sg_approach: roundToHundredth(sg_approach),
    sg_around_green: roundToHundredth(sg_around_green),
    sg_putting: roundToHundredth(sg_putting),
    sg_total: roundToHundredth(sg_total),
  };
}

/**
 * Calculate aggregate Strokes Gained for a full round
 */
export function calculateRoundStrokesGained(
  holes: HoleEntryData[],
  holeYardages?: number[]
): StrokesGainedResult {
  const result: StrokesGainedResult = {
    sg_off_tee: 0,
    sg_approach: 0,
    sg_around_green: 0,
    sg_putting: 0,
    sg_total: 0,
  };

  holes.forEach((hole, index) => {
    const yardage = holeYardages?.[index] || getDefaultYardage(hole.par);
    const holeSG = calculateHoleStrokesGained(hole, yardage);
    
    result.sg_off_tee += holeSG.sg_off_tee;
    result.sg_approach += holeSG.sg_approach;
    result.sg_around_green += holeSG.sg_around_green;
    result.sg_putting += holeSG.sg_putting;
    result.sg_total += holeSG.sg_total;
  });

  // Round final totals
  return {
    sg_off_tee: roundToHundredth(result.sg_off_tee),
    sg_approach: roundToHundredth(result.sg_approach),
    sg_around_green: roundToHundredth(result.sg_around_green),
    sg_putting: roundToHundredth(result.sg_putting),
    sg_total: roundToHundredth(result.sg_total),
  };
}

/**
 * Get per-round average Strokes Gained from multiple rounds
 */
export function calculateAverageStrokesGained(
  roundsData: StrokesGainedResult[]
): StrokesGainedResult {
  if (roundsData.length === 0) {
    return {
      sg_off_tee: 0,
      sg_approach: 0,
      sg_around_green: 0,
      sg_putting: 0,
      sg_total: 0,
    };
  }

  const totals = roundsData.reduce(
    (acc, round) => ({
      sg_off_tee: acc.sg_off_tee + round.sg_off_tee,
      sg_approach: acc.sg_approach + round.sg_approach,
      sg_around_green: acc.sg_around_green + round.sg_around_green,
      sg_putting: acc.sg_putting + round.sg_putting,
      sg_total: acc.sg_total + round.sg_total,
    }),
    { sg_off_tee: 0, sg_approach: 0, sg_around_green: 0, sg_putting: 0, sg_total: 0 }
  );

  const count = roundsData.length;
  return {
    sg_off_tee: roundToHundredth(totals.sg_off_tee / count),
    sg_approach: roundToHundredth(totals.sg_approach / count),
    sg_around_green: roundToHundredth(totals.sg_around_green / count),
    sg_putting: roundToHundredth(totals.sg_putting / count),
    sg_total: roundToHundredth(totals.sg_total / count),
  };
}

// === Helper Functions ===

function roundToHundredth(value: number): number {
  return Math.round(value * 100) / 100;
}

function estimateApproachDistance(par: number, holeYardage: number): number {
  // Estimate approach distance based on typical driving distances
  const avgDriveDistance = 250; // Average amateur drive
  
  switch (par) {
    case 3:
      return holeYardage; // Full distance on par 3
    case 4:
      return Math.max(50, holeYardage - avgDriveDistance);
    case 5:
      return 150; // Typical third shot distance
    default:
      return 150;
  }
}

function estimateFirstPuttDistance(gir: boolean, score: number, par: number, putts: number): number {
  // Estimate first putt distance based on typical scenarios
  if (gir) {
    // GIR typically means longer first putts
    return 25; // feet - average GIR first putt distance
  }
  
  // Missed green but got up and down
  if (score === par && putts === 1) {
    return 3; // feet - close chip/pitch
  }
  
  // Average missed green scenario
  return 15; // feet
}

function getDefaultYardage(par: number): number {
  switch (par) {
    case 3:
      return 165;
    case 4:
      return 400;
    case 5:
      return 520;
    default:
      return 400;
  }
}

function getExpectedFromMissedGreen(result: ApproachResult | null, distance: number): number {
  // Expected strokes from common miss positions around the green
  switch (result) {
    case "fringe":
      return 2.4;
    case "greenside_rough":
      return 2.6;
    case "bunker":
      return getExpectedFromBunker(20);
    case "short":
    case "long":
    case "left":
    case "right":
      return 2.55; // Average greenside miss
    default:
      return 2.55;
  }
}

function getExpectedFromChipPosition(result: ApproachResult | null): number {
  // Expected strokes to hole out from various short game positions
  switch (result) {
    case "fringe":
      return 2.3;
    case "greenside_rough":
      return 2.5;
    case "bunker":
      return 2.7;
    default:
      return 2.5;
  }
}

/**
 * Identify the weakest area of the game based on Strokes Gained
 */
export function identifyWeakestArea(sg: StrokesGainedResult): {
  area: string;
  value: number;
  recommendation: string;
} {
  const areas = [
    { area: "Off the Tee", value: sg.sg_off_tee, recommendation: "Focus on driving accuracy and distance control" },
    { area: "Approach", value: sg.sg_approach, recommendation: "Work on iron play and distance control with approaches" },
    { area: "Around the Green", value: sg.sg_around_green, recommendation: "Practice chipping, pitching, and bunker play" },
    { area: "Putting", value: sg.sg_putting, recommendation: "Focus on speed control and short putts" },
  ];

  // Find the lowest (most negative) SG value
  const weakest = areas.reduce((min, current) => 
    current.value < min.value ? current : min
  );

  return weakest;
}

/**
 * Identify the strongest area of the game based on Strokes Gained
 */
export function identifyStrongestArea(sg: StrokesGainedResult): {
  area: string;
  value: number;
} {
  const areas = [
    { area: "Off the Tee", value: sg.sg_off_tee },
    { area: "Approach", value: sg.sg_approach },
    { area: "Around the Green", value: sg.sg_around_green },
    { area: "Putting", value: sg.sg_putting },
  ];

  return areas.reduce((max, current) => 
    current.value > max.value ? current : max
  );
}

