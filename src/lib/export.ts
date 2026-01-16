import { Round, HoleScore } from "@/types/golf";

// Round data shape for CSV export
interface RoundForExport {
  played_at: string;
  course_name: string;
  total_score: number;
  total_putts: number | null;
  fairways_hit: number | null;
  fairways_total: number | null;
  gir: number | null;
  penalties: number | null;
  sg_total: number | null;
  sg_off_tee: number | null;
  sg_approach: number | null;
  sg_around_green: number | null;
  sg_putting: number | null;
  course_rating: number | null;
  slope_rating: number | null;
  scoring_format?: string;
}

// Convert rounds to CSV format
export function roundsToCSV(rounds: RoundForExport[]): string {
  const headers = [
    "Date",
    "Course",
    "Score",
    "To Par",
    "Putts",
    "Fairways Hit",
    "Fairways Total",
    "GIR",
    "Penalties",
    "SG Total",
    "SG Off Tee",
    "SG Approach",
    "SG Around Green",
    "SG Putting",
    "Course Rating",
    "Slope Rating",
    "Scoring Format",
  ];

  const rows = rounds.map((round) => {
    const totalPar = 72; // Default, could be calculated from holes
    return [
      round.played_at,
      `"${round.course_name}"`, // Quote in case of commas
      round.total_score,
      round.total_score - totalPar,
      round.total_putts,
      round.fairways_hit,
      round.fairways_total,
      round.gir,
      round.penalties,
      round.sg_total?.toFixed(2) || "N/A",
      round.sg_off_tee?.toFixed(2) || "N/A",
      round.sg_approach?.toFixed(2) || "N/A",
      round.sg_around_green?.toFixed(2) || "N/A",
      round.sg_putting?.toFixed(2) || "N/A",
      round.course_rating || "N/A",
      round.slope_rating || "N/A",
      round.scoring_format || "stroke",
    ];
  });

  return [headers.join(","), ...rows.map((row) => row.join(","))].join("\n");
}

// Convert a single round with holes to CSV
export function roundDetailToCSV(round: Round, holes: HoleScore[]): string {
  const roundInfo = [
    `Course,${round.course_name}`,
    `Date,${round.played_at}`,
    `Total Score,${round.total_score}`,
    `Course Rating,${round.course_rating || "N/A"}`,
    `Slope Rating,${round.slope_rating || "N/A"}`,
    "",
    "Hole-by-Hole Scores",
  ];

  const holeHeaders = [
    "Hole",
    "Par",
    "Score",
    "To Par",
    "Putts",
    "Fairway",
    "GIR",
    "Penalties",
    "SG Off Tee",
    "SG Approach",
    "SG Around Green",
    "SG Putting",
  ];

  const holeRows = holes.map((hole) => [
    hole.hole_number,
    hole.par,
    hole.score,
    hole.score - hole.par,
    hole.putts,
    hole.fairway_hit === null ? "N/A" : hole.fairway_hit ? "Yes" : "No",
    hole.gir ? "Yes" : "No",
    hole.penalties,
    hole.sg_off_tee?.toFixed(2) || "0.00",
    hole.sg_approach?.toFixed(2) || "0.00",
    hole.sg_around_green?.toFixed(2) || "0.00",
    hole.sg_putting?.toFixed(2) || "0.00",
  ]);

  // Add front 9 and back 9 totals
  const front9 = holes.slice(0, 9);
  const back9 = holes.slice(9);

  const front9Total = [
    "Front 9",
    front9.reduce((s, h) => s + h.par, 0),
    front9.reduce((s, h) => s + h.score, 0),
    front9.reduce((s, h) => s + (h.score - h.par), 0),
    front9.reduce((s, h) => s + h.putts, 0),
    "",
    "",
    "",
    "",
    "",
    "",
    "",
  ];

  const back9Total = [
    "Back 9",
    back9.reduce((s, h) => s + h.par, 0),
    back9.reduce((s, h) => s + h.score, 0),
    back9.reduce((s, h) => s + (h.score - h.par), 0),
    back9.reduce((s, h) => s + h.putts, 0),
    "",
    "",
    "",
    "",
    "",
    "",
    "",
  ];

  const total = [
    "Total",
    holes.reduce((s, h) => s + h.par, 0),
    round.total_score,
    round.total_score - holes.reduce((s, h) => s + h.par, 0),
    round.total_putts,
    `${round.fairways_hit}/${round.fairways_total}`,
    round.gir,
    round.penalties,
    round.sg_off_tee?.toFixed(2) || "0.00",
    round.sg_approach?.toFixed(2) || "0.00",
    round.sg_around_green?.toFixed(2) || "0.00",
    round.sg_putting?.toFixed(2) || "0.00",
  ];

  return [
    ...roundInfo,
    holeHeaders.join(","),
    ...holeRows.map((row) => row.join(",")),
    front9Total.join(","),
    back9Total.join(","),
    total.join(","),
  ].join("\n");
}

// Trigger download of CSV file
export function downloadCSV(content: string, filename: string): void {
  const blob = new Blob([content], { type: "text/csv;charset=utf-8;" });
  const link = document.createElement("a");
  const url = URL.createObjectURL(blob);

  link.setAttribute("href", url);
  link.setAttribute("download", filename);
  link.style.visibility = "hidden";

  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

// Club stats to CSV
export function clubStatsToCSV(clubs: Array<{
  name: string;
  brand?: string | null;
  model?: string | null;
  club_type: string;
  avg_distance?: number | null;
  total_shots?: number;
}>): string {
  const headers = ["Club", "Type", "Brand", "Model", "Avg Distance (yds)", "Total Shots"];

  const rows = clubs.map((club) => [
    `"${club.name}"`,
    club.club_type,
    club.brand || "",
    club.model || "",
    club.avg_distance || "N/A",
    club.total_shots || 0,
  ]);

  return [headers.join(","), ...rows.map((row) => row.join(","))].join("\n");
}
