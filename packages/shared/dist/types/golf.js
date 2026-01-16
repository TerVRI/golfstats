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
];
// Default hole data template
export const createDefaultHoleData = (holeNumber, par = 4) => ({
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
export const SCORING_FORMATS = [
    { value: 'stroke', label: 'Stroke Play', description: 'Traditional scoring - lowest total strokes wins' },
    { value: 'stableford', label: 'Stableford', description: 'Points-based system - highest points wins' },
    { value: 'match', label: 'Match Play', description: 'Hole-by-hole competition - win more holes' },
    { value: 'skins', label: 'Skins', description: 'Win the hole outright to take the skin' },
    { value: 'best_ball', label: 'Best Ball', description: 'Team format - best score counts' },
    { value: 'scramble', label: 'Scramble', description: 'Team format - everyone plays from best shot' },
];
// Stableford points calculator
export const calculateStablefordPoints = (score, par, handicapStrokes = 0) => {
    const netScore = score - handicapStrokes;
    const relative = netScore - par;
    if (relative <= -3)
        return 5; // Albatross or better
    if (relative === -2)
        return 4; // Eagle
    if (relative === -1)
        return 3; // Birdie
    if (relative === 0)
        return 2; // Par
    if (relative === 1)
        return 1; // Bogey
    return 0; // Double bogey or worse
};
