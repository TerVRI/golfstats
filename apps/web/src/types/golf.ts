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


// ============================================
// CLUB / BAG MANAGEMENT
// ============================================
export type ClubType = 'driver' | 'wood' | 'hybrid' | 'iron' | 'wedge' | 'putter';
export type ShaftMaterial = 'graphite' | 'steel';

export interface ClubData {
  id: string;
  user_id: string;
  name: string;
  brand: string | null;
  model: string | null;
  loft: number | null;
  shaft: string | null;
  shaft_material: ShaftMaterial | null;
  club_type: ClubType;
  purchase_date: string | null;
  in_bag: boolean;
  avg_distance: number | null;
  total_shots: number;
  notes: string | null;
  display_order: number;
  created_at: string;
  updated_at: string;
}

export interface ClubStats extends ClubData {
  avg_quality: number | null;
  greens_hit: number;
  fairways_hit: number;
}

// ============================================
// ACHIEVEMENTS / BADGES
// ============================================
export type AchievementCategory = 'scoring' | 'consistency' | 'improvement' | 'milestones' | 'social';
export type AchievementTier = 'bronze' | 'silver' | 'gold' | 'platinum';

export interface Achievement {
  id: string;
  name: string;
  description: string;
  icon: string;
  category: AchievementCategory;
  points: number;
  tier: AchievementTier;
  requirement_type: 'single' | 'cumulative' | 'streak';
  requirement_value: number;
}

export interface UserAchievement {
  id: string;
  user_id: string;
  achievement_id: string;
  unlocked_at: string;
  round_id: string | null;
  progress: number;
  achievement?: Achievement;
}

// ============================================
// SCORING FORMATS
// ============================================
export type ScoringFormat = 'stroke' | 'stableford' | 'match' | 'skins' | 'best_ball' | 'scramble';

export const SCORING_FORMATS: { value: ScoringFormat; label: string; description: string }[] = [
  { value: 'stroke', label: 'Stroke Play', description: 'Traditional scoring - lowest total strokes wins' },
  { value: 'stableford', label: 'Stableford', description: 'Points-based system - highest points wins' },
  { value: 'match', label: 'Match Play', description: 'Hole-by-hole competition - win more holes' },
  { value: 'skins', label: 'Skins', description: 'Win the hole outright to take the skin' },
  { value: 'best_ball', label: 'Best Ball', description: 'Team format - best score counts' },
  { value: 'scramble', label: 'Scramble', description: 'Team format - everyone plays from best shot' },
];

// Stableford points calculator
export const calculateStablefordPoints = (score: number, par: number, handicapStrokes: number = 0): number => {
  const netScore = score - handicapStrokes;
  const relative = netScore - par;
  
  if (relative <= -3) return 5; // Albatross or better
  if (relative === -2) return 4; // Eagle
  if (relative === -1) return 3; // Birdie
  if (relative === 0) return 2;  // Par
  if (relative === 1) return 1;  // Bogey
  return 0; // Double bogey or worse
};

// ============================================
// USER PREFERENCES
// ============================================
export type Theme = 'light' | 'dark';
export type Units = 'yards' | 'meters';
export type Tees = 'black' | 'blue' | 'white' | 'gold' | 'red';

export interface UserPreferences {
  theme: Theme;
  units: Units;
  default_tees: Tees;
  notifications: boolean;
  public_stats: boolean;
}
