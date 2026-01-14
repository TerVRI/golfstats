"use client";

import { use, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { StrokesGainedCard } from "@/components/stats";
import { cn, formatSG, calculateScoreToPar, getScoreColor, formatDate } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import { ArrowLeft, Calendar, Flag, Target, Pencil, Trash2, Loader2 } from "lucide-react";
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

interface Round {
  id: string;
  course_name: string;
  course_rating: number | null;
  slope_rating: number | null;
  played_at: string;
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
  notes: string | null;
}

interface HoleScore {
  id: string;
  hole_number: number;
  par: number;
  score: number;
  putts: number | null;
  fairway_hit: boolean | null;
  gir: boolean | null;
  penalties: number | null;
}

export default function RoundDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const supabase = createClient();
  
  const [round, setRound] = useState<Round | null>(null);
  const [holes, setHoles] = useState<HoleScore[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    async function fetchRound() {
      setIsLoading(true);
      setError(null);

      try {
        // Fetch round
        const { data: roundData, error: roundError } = await supabase
          .from("rounds")
          .select("*")
          .eq("id", id)
          .single();

        if (roundError) throw roundError;
        setRound(roundData);

        // Fetch hole scores
        const { data: holesData, error: holesError } = await supabase
          .from("hole_scores")
          .select("*")
          .eq("round_id", id)
          .order("hole_number");

        if (holesError) throw holesError;
        setHoles(holesData || []);
      } catch (err) {
        console.error("Error fetching round:", err);
        setError(err instanceof Error ? err.message : "Failed to load round");
      } finally {
        setIsLoading(false);
      }
    }

    fetchRound();
  }, [id, supabase]);

  const handleDelete = async () => {
    if (!confirm("Are you sure you want to delete this round? This cannot be undone.")) {
      return;
    }

    setIsDeleting(true);
    try {
      // Delete hole scores first (foreign key)
      await supabase.from("hole_scores").delete().eq("round_id", id);
      // Delete round
      const { error } = await supabase.from("rounds").delete().eq("id", id);
      if (error) throw error;
      router.push("/rounds");
    } catch (err) {
      console.error("Error deleting round:", err);
      alert("Failed to delete round");
    } finally {
      setIsDeleting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  if (error || !round) {
    return (
      <div className="text-center py-12">
        <p className="text-accent-red mb-4">{error || "Round not found"}</p>
        <Link href="/rounds">
          <Button>Back to Rounds</Button>
        </Link>
      </div>
    );
  }

  // Calculate derived values
  const totalPar = holes.reduce((sum, h) => sum + h.par, 0) || 72;
  const frontNine = holes.slice(0, 9);
  const backNine = holes.slice(9, 18);
  const frontNineScore = frontNine.reduce((sum, h) => sum + h.score, 0);
  const backNineScore = backNine.reduce((sum, h) => sum + h.score, 0);
  const frontNinePar = frontNine.reduce((sum, h) => sum + h.par, 0);
  const backNinePar = backNine.reduce((sum, h) => sum + h.par, 0);

  // Prepare chart data (use dummy SG per hole if not tracked individually)
  const holeByHoleData = holes.map((h) => ({
    hole: h.hole_number,
    sg: (h.par - h.score) * 0.5, // Simplified approximation
    score: h.score - h.par,
  }));

  const sgCumulativeData = holeByHoleData.reduce((acc, h, i) => {
    const prevValue = i > 0 ? acc[i - 1].cumulative : 0;
    acc.push({
      hole: h.hole,
      cumulative: Number((prevValue + h.sg).toFixed(2)),
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
            onClick={handleDelete}
            disabled={isDeleting}
          >
            {isDeleting ? (
              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
            ) : (
              <Trash2 className="w-4 h-4 mr-2" />
            )}
            Delete
          </Button>
        </div>
      </div>

      {/* Score Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Total Score</p>
            <p className={cn("text-4xl font-bold", getScoreColor(round.total_score, totalPar))}>
              {round.total_score}
            </p>
            <p className="text-sm text-foreground-muted mt-1">
              {calculateScoreToPar(round.total_score, totalPar)} to par
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Total Putts</p>
            <p className="text-4xl font-bold text-foreground">{round.total_putts ?? "-"}</p>
            <p className="text-sm text-foreground-muted mt-1">
              {round.total_putts ? `${(round.total_putts / 18).toFixed(1)} per hole` : "-"}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Fairways Hit</p>
            <p className="text-4xl font-bold text-foreground">
              {round.fairways_hit ?? "-"}/{round.fairways_total ?? "-"}
            </p>
            <p className="text-sm text-foreground-muted mt-1">
              {round.fairways_hit && round.fairways_total 
                ? `${((round.fairways_hit / round.fairways_total) * 100).toFixed(0)}%`
                : "-"}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Greens in Reg</p>
            <p className="text-4xl font-bold text-foreground">{round.gir ?? "-"}/18</p>
            <p className="text-sm text-foreground-muted mt-1">
              {round.gir 
                ? `${((round.gir / 18) * 100).toFixed(0)}%`
                : "-"}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Strokes Gained Cards */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <StrokesGainedCard
          category="total"
          value={round.sg_total ?? 0}
          label="Total SG"
        />
        <StrokesGainedCard
          category="off_tee"
          value={round.sg_off_tee ?? 0}
          label="SG: Off the Tee"
        />
        <StrokesGainedCard
          category="approach"
          value={round.sg_approach ?? 0}
          label="SG: Approach"
        />
        <StrokesGainedCard
          category="around_green"
          value={round.sg_around_green ?? 0}
          label="SG: Around Green"
        />
        <StrokesGainedCard
          category="putting"
          value={round.sg_putting ?? 0}
          label="SG: Putting"
        />
      </div>

      {/* Charts */}
      {holes.length > 0 && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Hole by Hole SG */}
          <Card>
            <CardHeader>
              <CardTitle>Score vs Par by Hole</CardTitle>
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
                      domain={[-3, 3]}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "#1e293b",
                        border: "1px solid #334155",
                        borderRadius: "8px",
                      }}
                      formatter={(value) => [value as number, "vs Par"]}
                    />
                    <ReferenceLine y={0} stroke="#475569" />
                    <Bar dataKey="score" radius={[4, 4, 0, 0]}>
                      {holeByHoleData.map((entry, index) => (
                        <Cell
                          key={`cell-${index}`}
                          fill={entry.score <= 0 ? "#10b981" : "#f43f5e"}
                        />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Cumulative Score */}
          <Card>
            <CardHeader>
              <CardTitle>Cumulative Score vs Par</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[250px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={holes.map((h, i) => ({
                    hole: h.hole_number,
                    cumulative: holes.slice(0, i + 1).reduce((sum, hole) => sum + (hole.score - hole.par), 0)
                  }))}>
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
                      formatter={(value) => [value as number, "vs Par"]}
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
      )}

      {/* Scorecard */}
      {holes.length > 0 && (
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
                      <th key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted font-medium w-10">
                        {h.hole_number}
                      </th>
                    ))}
                    <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-tertiary w-12">Out</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-b border-card-border">
                    <td className="py-2 px-2 text-foreground-muted">Par</td>
                    {frontNine.map((h) => (
                      <td key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted">{h.par}</td>
                    ))}
                    <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">{frontNinePar}</td>
                  </tr>
                  <tr className="border-b border-card-border">
                    <td className="py-2 px-2 text-foreground font-medium">Score</td>
                    {frontNine.map((h) => (
                      <td key={h.hole_number} className={cn("py-2 px-2 text-center font-bold", getScoreColor(h.score, h.par))}>
                        {h.score}
                      </td>
                    ))}
                    <td className="py-2 px-2 text-center font-bold text-foreground bg-background-tertiary">{frontNineScore}</td>
                  </tr>
                  <tr className="border-b border-card-border">
                    <td className="py-2 px-2 text-foreground-muted">Putts</td>
                    {frontNine.map((h) => (
                      <td key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted">{h.putts ?? "-"}</td>
                    ))}
                    <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                      {frontNine.reduce((sum, h) => sum + (h.putts ?? 0), 0)}
                    </td>
                  </tr>
                  <tr className="border-b border-card-border">
                    <td className="py-2 px-2 text-foreground-muted">FIR</td>
                    {frontNine.map((h) => (
                      <td key={h.hole_number} className="py-2 px-2 text-center">
                        {h.fairway_hit === null ? (
                          <span className="text-foreground-muted">-</span>
                        ) : h.fairway_hit ? (
                          <span className="text-accent-green">✓</span>
                        ) : (
                          <span className="text-accent-red">✗</span>
                        )}
                      </td>
                    ))}
                    <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                      {frontNine.filter((h) => h.fairway_hit).length}/{frontNine.filter((h) => h.fairway_hit !== null).length}
                    </td>
                  </tr>
                  <tr>
                    <td className="py-2 px-2 text-foreground-muted">GIR</td>
                    {frontNine.map((h) => (
                      <td key={h.hole_number} className="py-2 px-2 text-center">
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
              {backNine.length > 0 && (
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-card-border">
                      <th className="py-2 px-2 text-left text-foreground-muted font-medium w-16">Hole</th>
                      {backNine.map((h) => (
                        <th key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted font-medium w-10">
                          {h.hole_number}
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
                        <td key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted">{h.par}</td>
                      ))}
                      <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">{backNinePar}</td>
                      <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">{totalPar}</td>
                    </tr>
                    <tr className="border-b border-card-border">
                      <td className="py-2 px-2 text-foreground font-medium">Score</td>
                      {backNine.map((h) => (
                        <td key={h.hole_number} className={cn("py-2 px-2 text-center font-bold", getScoreColor(h.score, h.par))}>
                          {h.score}
                        </td>
                      ))}
                      <td className="py-2 px-2 text-center font-bold text-foreground bg-background-tertiary">{backNineScore}</td>
                      <td className={cn("py-2 px-2 text-center font-bold bg-background-secondary", getScoreColor(round.total_score, totalPar))}>
                        {round.total_score}
                      </td>
                    </tr>
                    <tr className="border-b border-card-border">
                      <td className="py-2 px-2 text-foreground-muted">Putts</td>
                      {backNine.map((h) => (
                        <td key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted">{h.putts ?? "-"}</td>
                      ))}
                      <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                        {backNine.reduce((sum, h) => sum + (h.putts ?? 0), 0)}
                      </td>
                      <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">{round.total_putts ?? "-"}</td>
                    </tr>
                    <tr className="border-b border-card-border">
                      <td className="py-2 px-2 text-foreground-muted">FIR</td>
                      {backNine.map((h) => (
                        <td key={h.hole_number} className="py-2 px-2 text-center">
                          {h.fairway_hit === null ? (
                            <span className="text-foreground-muted">-</span>
                          ) : h.fairway_hit ? (
                            <span className="text-accent-green">✓</span>
                          ) : (
                            <span className="text-accent-red">✗</span>
                          )}
                        </td>
                      ))}
                      <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                        {backNine.filter((h) => h.fairway_hit).length}/{backNine.filter((h) => h.fairway_hit !== null).length}
                      </td>
                      <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">
                        {round.fairways_hit ?? "-"}/{round.fairways_total ?? "-"}
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2 px-2 text-foreground-muted">GIR</td>
                      {backNine.map((h) => (
                        <td key={h.hole_number} className="py-2 px-2 text-center">
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
                        {round.gir ?? "-"}/18
                      </td>
                    </tr>
                  </tbody>
                </table>
              )}
            </div>
          </CardContent>
        </Card>
      )}

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
