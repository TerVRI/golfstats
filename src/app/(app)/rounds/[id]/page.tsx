"use client";

import { use } from "react";
import Link from "next/link";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { StrokesGainedCard } from "@/components/stats";
import { cn, formatSG, calculateScoreToPar, getScoreColor, formatDate } from "@/lib/utils";
import { ArrowLeft, Calendar, Flag, Target, Pencil, Trash2 } from "lucide-react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
  LineChart,
  Line,
  ReferenceLine,
} from "recharts";

// Demo data - would come from database in production
const demoRound = {
  id: "1",
  course_name: "Pebble Beach Golf Links",
  course_rating: 72.0,
  slope_rating: 130,
  played_at: "2026-01-10",
  total_score: 82,
  total_par: 72,
  total_putts: 32,
  fairways_hit: 8,
  fairways_total: 14,
  gir: 9,
  penalties: 2,
  sg_total: -0.84,
  sg_off_tee: 0.52,
  sg_approach: -1.12,
  sg_around_green: -0.24,
  sg_putting: 0.00,
  notes: "Wind was tough on the back nine. Approach shots were inconsistent.",
  holes: [
    { hole: 1, par: 4, score: 5, putts: 2, fir: true, gir: false, sg_total: -0.32 },
    { hole: 2, par: 5, score: 5, putts: 2, fir: true, gir: true, sg_total: 0.45 },
    { hole: 3, par: 4, score: 4, putts: 2, fir: false, gir: true, sg_total: 0.12 },
    { hole: 4, par: 4, score: 5, putts: 2, fir: true, gir: false, sg_total: -0.28 },
    { hole: 5, par: 3, score: 3, putts: 2, fir: null, gir: true, sg_total: 0.22 },
    { hole: 6, par: 5, score: 6, putts: 3, fir: false, gir: false, sg_total: -0.65 },
    { hole: 7, par: 3, score: 4, putts: 2, fir: null, gir: false, sg_total: -0.45 },
    { hole: 8, par: 4, score: 4, putts: 1, fir: true, gir: true, sg_total: 0.38 },
    { hole: 9, par: 4, score: 5, putts: 2, fir: true, gir: false, sg_total: -0.18 },
    { hole: 10, par: 4, score: 4, putts: 2, fir: true, gir: true, sg_total: 0.15 },
    { hole: 11, par: 4, score: 5, putts: 2, fir: false, gir: false, sg_total: -0.42 },
    { hole: 12, par: 3, score: 3, putts: 1, fir: null, gir: true, sg_total: 0.55 },
    { hole: 13, par: 4, score: 5, putts: 2, fir: true, gir: false, sg_total: -0.35 },
    { hole: 14, par: 5, score: 5, putts: 2, fir: true, gir: true, sg_total: 0.28 },
    { hole: 15, par: 4, score: 4, putts: 2, fir: false, gir: true, sg_total: 0.08 },
    { hole: 16, par: 4, score: 5, putts: 2, fir: false, gir: false, sg_total: -0.52 },
    { hole: 17, par: 3, score: 4, putts: 2, fir: null, gir: false, sg_total: -0.38 },
    { hole: 18, par: 5, score: 6, putts: 2, fir: false, gir: false, sg_total: -0.52 },
  ],
};

export default function RoundDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const round = demoRound; // In production, fetch by id

  const frontNine = round.holes.slice(0, 9);
  const backNine = round.holes.slice(9, 18);
  const frontNineScore = frontNine.reduce((sum, h) => sum + h.score, 0);
  const backNineScore = backNine.reduce((sum, h) => sum + h.score, 0);
  const frontNinePar = frontNine.reduce((sum, h) => sum + h.par, 0);
  const backNinePar = backNine.reduce((sum, h) => sum + h.par, 0);

  // Prepare chart data
  const holeByHoleData = round.holes.map((h) => ({
    hole: h.hole,
    sg: h.sg_total,
    score: h.score - h.par,
  }));

  const sgCumulativeData = round.holes.reduce((acc, h, i) => {
    const prevValue = i > 0 ? acc[i - 1].cumulative : 0;
    acc.push({
      hole: h.hole,
      cumulative: Number((prevValue + h.sg_total).toFixed(2)),
    });
    return acc;
  }, [] as { hole: number; cumulative: number }[]);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
        <div>
          <Link
            href="/rounds"
            className="inline-flex items-center gap-2 text-foreground-muted hover:text-foreground transition-colors mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Rounds
          </Link>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">{round.course_name}</h1>
          <div className="flex items-center gap-4 mt-2 text-foreground-muted">
            <div className="flex items-center gap-2">
              <Calendar className="w-4 h-4" />
              {formatDate(round.played_at)}
            </div>
            {round.course_rating && (
              <span>Rating: {round.course_rating}</span>
            )}
            {round.slope_rating && (
              <span>Slope: {round.slope_rating}</span>
            )}
          </div>
        </div>
        <div className="flex gap-2">
          <Button 
            variant="secondary" 
            size="sm"
            onClick={() => alert("Edit functionality coming soon!")}
          >
            <Pencil className="w-4 h-4 mr-2" />
            Edit
          </Button>
          <Button 
            variant="danger" 
            size="sm"
            onClick={() => {
              if (confirm("Are you sure you want to delete this round?")) {
                alert("Delete functionality coming soon!");
              }
            }}
          >
            <Trash2 className="w-4 h-4 mr-2" />
            Delete
          </Button>
        </div>
      </div>

      {/* Score Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Total Score</p>
            <p className={cn("text-4xl font-bold", getScoreColor(round.total_score, round.total_par))}>
              {round.total_score}
            </p>
            <p className="text-sm text-foreground-muted mt-1">
              {calculateScoreToPar(round.total_score, round.total_par)} to par
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Total Putts</p>
            <p className="text-4xl font-bold text-foreground">{round.total_putts}</p>
            <p className="text-sm text-foreground-muted mt-1">
              {(round.total_putts / 18).toFixed(1)} per hole
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Fairways Hit</p>
            <p className="text-4xl font-bold text-foreground">
              {round.fairways_hit}/{round.fairways_total}
            </p>
            <p className="text-sm text-foreground-muted mt-1">
              {((round.fairways_hit / round.fairways_total) * 100).toFixed(0)}%
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Greens in Reg</p>
            <p className="text-4xl font-bold text-foreground">{round.gir}/18</p>
            <p className="text-sm text-foreground-muted mt-1">
              {((round.gir / 18) * 100).toFixed(0)}%
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Strokes Gained Cards */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <StrokesGainedCard
          category="total"
          value={round.sg_total}
          label="Total SG"
        />
        <StrokesGainedCard
          category="off_tee"
          value={round.sg_off_tee}
          label="SG: Off the Tee"
        />
        <StrokesGainedCard
          category="approach"
          value={round.sg_approach}
          label="SG: Approach"
        />
        <StrokesGainedCard
          category="around_green"
          value={round.sg_around_green}
          label="SG: Around Green"
        />
        <StrokesGainedCard
          category="putting"
          value={round.sg_putting}
          label="SG: Putting"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Hole by Hole SG */}
        <Card>
          <CardHeader>
            <CardTitle>Strokes Gained by Hole</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={holeByHoleData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                  <XAxis
                    dataKey="hole"
                    tick={{ fill: "#94a3b8", fontSize: 10 }}
                    axisLine={{ stroke: "#334155" }}
                  />
                  <YAxis
                    tick={{ fill: "#94a3b8", fontSize: 10 }}
                    axisLine={{ stroke: "#334155" }}
                    domain={[-1, 1]}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#1e293b",
                      border: "1px solid #334155",
                      borderRadius: "8px",
                    }}
                    formatter={(value) => [formatSG(value as number), "SG"]}
                  />
                  <ReferenceLine y={0} stroke="#475569" />
                  <Bar dataKey="sg" radius={[4, 4, 0, 0]}>
                    {holeByHoleData.map((entry, index) => (
                      <Cell
                        key={`cell-${index}`}
                        fill={entry.sg >= 0 ? "#10b981" : "#f43f5e"}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Cumulative SG */}
        <Card>
          <CardHeader>
            <CardTitle>Cumulative Strokes Gained</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={sgCumulativeData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                  <XAxis
                    dataKey="hole"
                    tick={{ fill: "#94a3b8", fontSize: 10 }}
                    axisLine={{ stroke: "#334155" }}
                  />
                  <YAxis
                    tick={{ fill: "#94a3b8", fontSize: 10 }}
                    axisLine={{ stroke: "#334155" }}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#1e293b",
                      border: "1px solid #334155",
                      borderRadius: "8px",
                    }}
                    formatter={(value) => [formatSG(value as number), "Cumulative SG"]}
                  />
                  <ReferenceLine y={0} stroke="#475569" strokeDasharray="3 3" />
                  <Line
                    type="monotone"
                    dataKey="cumulative"
                    stroke="#3b82f6"
                    strokeWidth={2}
                    dot={{ fill: "#3b82f6", strokeWidth: 0, r: 3 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Scorecard */}
      <Card>
        <CardHeader>
          <CardTitle>Scorecard</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            {/* Front Nine */}
            <table className="w-full text-sm mb-6">
              <thead>
                <tr className="border-b border-card-border">
                  <th className="py-2 px-2 text-left text-foreground-muted font-medium w-16">Hole</th>
                  {frontNine.map((h) => (
                    <th key={h.hole} className="py-2 px-2 text-center text-foreground-muted font-medium w-10">
                      {h.hole}
                    </th>
                  ))}
                  <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-tertiary w-12">Out</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground-muted">Par</td>
                  {frontNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center text-foreground-muted">{h.par}</td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">{frontNinePar}</td>
                </tr>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground font-medium">Score</td>
                  {frontNine.map((h) => (
                    <td key={h.hole} className={cn("py-2 px-2 text-center font-bold", getScoreColor(h.score, h.par))}>
                      {h.score}
                    </td>
                  ))}
                  <td className="py-2 px-2 text-center font-bold text-foreground bg-background-tertiary">{frontNineScore}</td>
                </tr>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground-muted">Putts</td>
                  {frontNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center text-foreground-muted">{h.putts}</td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                    {frontNine.reduce((sum, h) => sum + h.putts, 0)}
                  </td>
                </tr>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground-muted">FIR</td>
                  {frontNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center">
                      {h.fir === null ? (
                        <span className="text-foreground-muted">-</span>
                      ) : h.fir ? (
                        <span className="text-accent-green">✓</span>
                      ) : (
                        <span className="text-accent-red">✗</span>
                      )}
                    </td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                    {frontNine.filter((h) => h.fir).length}/{frontNine.filter((h) => h.fir !== null).length}
                  </td>
                </tr>
                <tr>
                  <td className="py-2 px-2 text-foreground-muted">GIR</td>
                  {frontNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center">
                      {h.gir ? (
                        <span className="text-accent-green">✓</span>
                      ) : (
                        <span className="text-accent-red">✗</span>
                      )}
                    </td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                    {frontNine.filter((h) => h.gir).length}/9
                  </td>
                </tr>
              </tbody>
            </table>

            {/* Back Nine */}
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-card-border">
                  <th className="py-2 px-2 text-left text-foreground-muted font-medium w-16">Hole</th>
                  {backNine.map((h) => (
                    <th key={h.hole} className="py-2 px-2 text-center text-foreground-muted font-medium w-10">
                      {h.hole}
                    </th>
                  ))}
                  <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-tertiary w-12">In</th>
                  <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-secondary w-12">Tot</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground-muted">Par</td>
                  {backNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center text-foreground-muted">{h.par}</td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">{backNinePar}</td>
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">{round.total_par}</td>
                </tr>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground font-medium">Score</td>
                  {backNine.map((h) => (
                    <td key={h.hole} className={cn("py-2 px-2 text-center font-bold", getScoreColor(h.score, h.par))}>
                      {h.score}
                    </td>
                  ))}
                  <td className="py-2 px-2 text-center font-bold text-foreground bg-background-tertiary">{backNineScore}</td>
                  <td className={cn("py-2 px-2 text-center font-bold bg-background-secondary", getScoreColor(round.total_score, round.total_par))}>
                    {round.total_score}
                  </td>
                </tr>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground-muted">Putts</td>
                  {backNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center text-foreground-muted">{h.putts}</td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                    {backNine.reduce((sum, h) => sum + h.putts, 0)}
                  </td>
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">{round.total_putts}</td>
                </tr>
                <tr className="border-b border-card-border">
                  <td className="py-2 px-2 text-foreground-muted">FIR</td>
                  {backNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center">
                      {h.fir === null ? (
                        <span className="text-foreground-muted">-</span>
                      ) : h.fir ? (
                        <span className="text-accent-green">✓</span>
                      ) : (
                        <span className="text-accent-red">✗</span>
                      )}
                    </td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                    {backNine.filter((h) => h.fir).length}/{backNine.filter((h) => h.fir !== null).length}
                  </td>
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">
                    {round.fairways_hit}/{round.fairways_total}
                  </td>
                </tr>
                <tr>
                  <td className="py-2 px-2 text-foreground-muted">GIR</td>
                  {backNine.map((h) => (
                    <td key={h.hole} className="py-2 px-2 text-center">
                      {h.gir ? (
                        <span className="text-accent-green">✓</span>
                      ) : (
                        <span className="text-accent-red">✗</span>
                      )}
                    </td>
                  ))}
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                    {backNine.filter((h) => h.gir).length}/9
                  </td>
                  <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">
                    {round.gir}/18
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Notes */}
      {round.notes && (
        <Card>
          <CardHeader>
            <CardTitle>Notes</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-foreground-muted">{round.notes}</p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

