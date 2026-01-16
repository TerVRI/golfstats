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
    fairway_hit: boolean | null;
    gir: boolean;
    penalties: number;
    tee_club: string | null;
    approach_distance: number | null;
    approach_club: string | null;
    approach_result: ApproachResult | null;
    up_and_down: boolean | null;
    sand_save: boolean | null;
    first_putt_distance: number | null;
    sg_off_tee: number;
    sg_approach: number;
    sg_around_green: number;
    sg_putting: number;
    created_at: string;
}
export type ApproachResult = "green" | "fringe" | "greenside_rough" | "bunker" | "short" | "long" | "left" | "right";
export interface RoundWithHoles extends Round {
    holes: HoleScore[];
}
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
export declare const CLUBS: readonly ["Driver", "3 Wood", "5 Wood", "7 Wood", "Hybrid", "2 Iron", "3 Iron", "4 Iron", "5 Iron", "6 Iron", "7 Iron", "8 Iron", "9 Iron", "PW", "GW", "SW", "LW", "Putter"];
export type Club = (typeof CLUBS)[number];
export declare const createDefaultHoleData: (holeNumber: number, par?: number) => HoleEntryData;
export declare const DEFAULT_COURSE_PARS: number[];
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
export type ScoringFormat = 'stroke' | 'stableford' | 'match' | 'skins' | 'best_ball' | 'scramble';
export declare const SCORING_FORMATS: {
    value: ScoringFormat;
    label: string;
    description: string;
}[];
export declare const calculateStablefordPoints: (score: number, par: number, handicapStrokes?: number) => number;
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
//# sourceMappingURL=golf.d.ts.map