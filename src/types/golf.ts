export interface User {
  id: string;
  email: string;
  name: string;
  handicap: number | null;
  created_at: string;
  updated_at: string;
}

export interface Round {
  id: string;
  user_id: string;
  course_name: string;
  course_rating: number | null;
  slope_rating: number | null;
  played_at: string;
  total_score: number;
  total_putts: number;
  fairways_hit: number;
  fairways_total: number;
  gir: number;
  penalties: number;
  // Strokes Gained totals for the round
  sg_total: number;
  sg_off_tee: number;
  sg_approach: number;
  sg_around_green: number;
  sg_putting: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface HoleScore {
  id: string;
  round_id: string;
  hole_number: number;
  par: number;
  score: number;
  putts: number;
  fairway_hit: boolean | null; // null for par 3s
  gir: boolean;
  penalties: number;
  // Shot tracking
  tee_club: string | null;
  approach_distance: number | null; // yards
  approach_club: string | null;
  approach_result: ApproachResult | null;
  up_and_down: boolean | null;
  sand_save: boolean | null;
  first_putt_distance: number | null; // feet
  // Strokes Gained per hole
  sg_off_tee: number;
  sg_approach: number;
  sg_around_green: number;
  sg_putting: number;
  created_at: string;
}

export type ApproachResult = 
  | "green" 
  | "fringe" 
  | "greenside_rough" 
  | "bunker" 
  | "short" 
  | "long" 
  | "left" 
  | "right";

export interface RoundWithHoles extends Round {
  holes: HoleScore[];
}

// For the round entry form
export interface HoleEntryData {
  hole_number: number;
  par: number;
  score: number;
  putts: number;
  fairway_hit: boolean | null;
  gir: boolean;
  penalties: number;
  tee_club: string | null;
  approach_distance: number | null;
  approach_club: string | null;
  approach_result: ApproachResult | null;
  first_putt_distance: number | null;
}

export interface RoundEntryData {
  course_name: string;
  course_rating: number | null;
  slope_rating: number | null;
  played_at: string;
  notes: string | null;
  holes: HoleEntryData[];
}

// Stats aggregation
export interface StrokesGainedSummary {
  sg_total: number;
  sg_off_tee: number;
  sg_approach: number;
  sg_around_green: number;
  sg_putting: number;
  rounds_count: number;
}

export interface RoundStats {
  averageScore: number;
  averagePutts: number;
  fairwayPercentage: number;
  girPercentage: number;
  strokesGained: StrokesGainedSummary;
}

// Club options
export const CLUBS = [
  "Driver",
  "3 Wood",
  "5 Wood",
  "7 Wood",
  "Hybrid",
  "2 Iron",
  "3 Iron",
  "4 Iron",
  "5 Iron",
  "6 Iron",
  "7 Iron",
  "8 Iron",
  "9 Iron",
  "PW",
  "GW",
  "SW",
  "LW",
  "Putter",
] as const;

export type Club = (typeof CLUBS)[number];

// Default hole data template
export const createDefaultHoleData = (holeNumber: number, par: number = 4): HoleEntryData => ({
  hole_number: holeNumber,
  par,
  score: par,
  putts: 2,
  fairway_hit: par === 3 ? null : null,
  gir: false,
  penalties: 0,
  tee_club: par === 3 ? null : "Driver",
  approach_distance: null,
  approach_club: null,
  approach_result: null,
  first_putt_distance: null,
});

// Standard 18 holes with typical par configuration
export const DEFAULT_COURSE_PARS = [4, 4, 3, 5, 4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 5];

