"use client";

import { useEffect, useState } from "react";
import { StrokesGainedCard, StatCard } from "@/components/stats";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { formatSG, calculateScoreToPar, getScoreColor, formatDate } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";
import {
  PlusCircle,
  Trophy,
  Target,
  Flag,
  TrendingUp,
  Calendar,
  ArrowRight,
  Loader2,
} from "lucide-react";
import {
  ResponsiveContainer,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  Radar,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
} from "recharts";

interface Round {
  id: string;
  course_name: string;
  played_at: string;
  total_score: number;
  sg_total: number | null;
  sg_off_tee: number | null;
  sg_approach: number | null;
  sg_around_green: number | null;
  sg_putting: number | null;
}

export default function DashboardPage() {
  const supabase = createClient();
  const [rounds, setRounds] = useState<Round[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchRounds() {
      setIsLoading(true);
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          setRounds([]);
          setIsLoading(false);
          return;
        }

        const { data, error } = await supabase
          .from("rounds")
          .select("id, course_name, played_at, total_score, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting")
          .eq("user_id", user.id)
          .order("played_at", { ascending: false })
          .limit(10);

        if (error) throw error;
        setRounds(data || []);
      } catch (err) {
        console.error("Error fetching rounds:", err);
      } finally {
        setIsLoading(false);
      }
    }

    fetchRounds();
  }, [supabase]);

  // Calculate averages from real data
  const roundsCount = rounds.length;
  const avgScore = roundsCount > 0
    ? Math.round(rounds.reduce((sum, r) => sum + r.total_score, 0) / roundsCount)
    : 0;
  const bestRound = roundsCount > 0
    ? rounds.reduce((best, r) => r.total_score < best.total_score ? r : best, rounds[0])
    : null;

  const avgStrokesGained = {
    sg_total: roundsCount > 0 ? rounds.reduce((sum, r) => sum + (r.sg_total || 0), 0) / roundsCount : 0,
    sg_off_tee: roundsCount > 0 ? rounds.reduce((sum, r) => sum + (r.sg_off_tee || 0), 0) / roundsCount : 0,
    sg_approach: roundsCount > 0 ? rounds.reduce((sum, r) => sum + (r.sg_approach || 0), 0) / roundsCount : 0,
    sg_around_green: roundsCount > 0 ? rounds.reduce((sum, r) => sum + (r.sg_around_green || 0), 0) / roundsCount : 0,
    sg_putting: roundsCount > 0 ? rounds.reduce((sum, r) => sum + (r.sg_putting || 0), 0) / roundsCount : 0,
  };

  // Calculate improvement (last 3 vs previous 3)
  const improvement = roundsCount >= 6
    ? (rounds.slice(0, 3).reduce((sum, r) => sum + (r.sg_total || 0), 0) / 3) -
      (rounds.slice(3, 6).reduce((sum, r) => sum + (r.sg_total || 0), 0) / 3)
    : 0;

  // Find weakest area
  const sgCategories = [
    { name: "Approach", value: avgStrokesGained.sg_approach, key: "approach" },
    { name: "Off Tee", value: avgStrokesGained.sg_off_tee, key: "off_tee" },
    { name: "Around Green", value: avgStrokesGained.sg_around_green, key: "around_green" },
    { name: "Putting", value: avgStrokesGained.sg_putting, key: "putting" },
  ];
  const weakestArea = sgCategories.reduce((worst, cat) => cat.value < worst.value ? cat : worst, sgCategories[0]);

  const radarData = [
    { category: "Off Tee", value: avgStrokesGained.sg_off_tee + 2, fullMark: 4 },
    { category: "Approach", value: avgStrokesGained.sg_approach + 2, fullMark: 4 },
    { category: "Around Green", value: avgStrokesGained.sg_around_green + 2, fullMark: 4 },
    { category: "Putting", value: avgStrokesGained.sg_putting + 2, fullMark: 4 },
  ];

  const sgBreakdownData = [
    { name: "Off Tee", value: avgStrokesGained.sg_off_tee },
    { name: "Approach", value: avgStrokesGained.sg_approach },
    { name: "Around Green", value: avgStrokesGained.sg_around_green },
    { name: "Putting", value: avgStrokesGained.sg_putting },
  ];

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  // Empty state
  if (rounds.length === 0) {
    return (
      <div className="space-y-8 animate-fade-in">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-foreground">Dashboard</h1>
            <p className="text-foreground-muted mt-1">
              Your strokes gained analysis at a glance
            </p>
          </div>
        </div>

        <Card>
          <CardContent className="py-16 text-center">
            <Target className="w-16 h-16 text-foreground-muted mx-auto mb-6" />
            <h2 className="text-2xl font-bold text-foreground mb-2">No Rounds Yet</h2>
            <p className="text-foreground-muted mb-6 max-w-md mx-auto">
              Start tracking your rounds to see your strokes gained analysis and identify areas for improvement.
            </p>
            <Link href="/rounds/new">
              <Button size="lg">
                <PlusCircle className="w-5 h-5 mr-2" />
                Log Your First Round
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Dashboard</h1>
          <p className="text-foreground-muted mt-1">
            Your strokes gained analysis at a glance
          </p>
        </div>
        <Link href="/rounds/new">
          <Button size="lg" className="w-full sm:w-auto">
            <PlusCircle className="w-5 h-5 mr-2" />
            Log New Round
          </Button>
        </Link>
      </div>

      {/* Strokes Gained Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <StrokesGainedCard
          category="total"
          value={avgStrokesGained.sg_total}
          label="Total SG"
          description="Per round average"
          className="lg:col-span-1"
        />
        <StrokesGainedCard
          category="off_tee"
          value={avgStrokesGained.sg_off_tee}
          label="SG: Off the Tee"
        />
        <StrokesGainedCard
          category="approach"
          value={avgStrokesGained.sg_approach}
          label="SG: Approach"
        />
        <StrokesGainedCard
          category="around_green"
          value={avgStrokesGained.sg_around_green}
          label="SG: Around Green"
        />
        <StrokesGainedCard
          category="putting"
          value={avgStrokesGained.sg_putting}
          label="SG: Putting"
        />
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          label="Rounds Played"
          value={roundsCount}
          icon={Calendar}
          subtitle="Total tracked"
          color="blue"
        />
        <StatCard
          label="Average Score"
          value={avgScore}
          icon={Trophy}
          subtitle="vs par 72"
          color="amber"
        />
        <StatCard
          label="Best Round"
          value={bestRound?.total_score ?? "-"}
          icon={Target}
          subtitle={bestRound?.course_name ?? ""}
          color="green"
        />
        <StatCard
          label="Improvement"
          value={improvement >= 0 ? `+${improvement.toFixed(1)}` : improvement.toFixed(1)}
          icon={TrendingUp}
          subtitle="SG trend"
          color={improvement >= 0 ? "green" : "red"}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Radar Chart */}
        <Card>
          <CardHeader>
            <CardTitle>Game Profile</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <RadarChart data={radarData}>
                  <PolarGrid stroke="#334155" />
                  <PolarAngleAxis
                    dataKey="category"
                    tick={{ fill: "#94a3b8", fontSize: 12 }}
                  />
                  <Radar
                    name="Performance"
                    dataKey="value"
                    stroke="#10b981"
                    fill="#10b981"
                    fillOpacity={0.3}
                    strokeWidth={2}
                  />
                </RadarChart>
              </ResponsiveContainer>
            </div>
            <p className="text-sm text-foreground-muted text-center mt-4">
              Higher values indicate better performance in each category
            </p>
          </CardContent>
        </Card>

        {/* Bar Chart */}
        <Card>
          <CardHeader>
            <CardTitle>Strokes Gained Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={sgBreakdownData} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" horizontal={false} />
                  <XAxis
                    type="number"
                    domain={[-2, 2]}
                    tick={{ fill: "#94a3b8", fontSize: 12 }}
                    axisLine={{ stroke: "#334155" }}
                  />
                  <YAxis
                    type="category"
                    dataKey="name"
                    tick={{ fill: "#94a3b8", fontSize: 12 }}
                    axisLine={{ stroke: "#334155" }}
                    width={100}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#1e293b",
                      border: "1px solid #334155",
                      borderRadius: "8px",
                    }}
                    formatter={(value) => [formatSG(value as number), "SG"]}
                  />
                  <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                    {sgBreakdownData.map((entry, index) => (
                      <Cell
                        key={`cell-${index}`}
                        fill={entry.value >= 0 ? "#10b981" : "#f43f5e"}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
            <div className="flex items-center justify-center gap-6 mt-4 text-sm">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded bg-accent-green" />
                <span className="text-foreground-muted">Gaining</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded bg-accent-red" />
                <span className="text-foreground-muted">Losing</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Recent Rounds */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Recent Rounds</CardTitle>
          <Link href="/rounds" className="text-sm text-accent-green hover:text-accent-green-light flex items-center gap-1">
            View all
            <ArrowRight className="w-4 h-4" />
          </Link>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {rounds.slice(0, 4).map((round) => (
              <Link
                key={round.id}
                href={`/rounds/${round.id}`}
                className="flex items-center justify-between p-4 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className="w-10 h-10 rounded-full bg-accent-green/10 flex items-center justify-center">
                    <Flag className="w-5 h-5 text-accent-green" />
                  </div>
                  <div>
                    <p className="font-medium text-foreground">{round.course_name}</p>
                    <p className="text-sm text-foreground-muted">{formatDate(round.played_at)}</p>
                  </div>
                </div>
                <div className="flex items-center gap-6">
                  <div className="text-right">
                    <p className={`text-lg font-bold ${getScoreColor(round.total_score, 72)}`}>
                      {round.total_score}
                    </p>
                    <p className="text-xs text-foreground-muted">
                      {calculateScoreToPar(round.total_score, 72)}
                    </p>
                  </div>
                  <div className="text-right min-w-[60px]">
                    <p className={`text-lg font-bold ${(round.sg_total ?? 0) >= 0 ? "text-accent-green" : "text-accent-red"}`}>
                      {formatSG(round.sg_total ?? 0)}
                    </p>
                    <p className="text-xs text-foreground-muted">SG</p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Insight Card */}
      {weakestArea && weakestArea.value < 0 && (
        <Card className="bg-gradient-to-br from-background-secondary to-background-tertiary border-accent-amber/20">
          <CardContent className="py-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-xl bg-accent-amber/10 flex items-center justify-center flex-shrink-0">
                <Target className="w-6 h-6 text-accent-amber" />
              </div>
              <div>
                <h3 className="font-semibold text-foreground mb-1">Focus Area: {weakestArea.name}</h3>
                <p className="text-foreground-muted text-sm">
                  Your {weakestArea.name.toLowerCase()} shots are costing you{" "}
                  <span className="text-accent-red font-medium">{Math.abs(weakestArea.value).toFixed(2)} strokes per round</span>.
                  This is your biggest opportunity for improvement. Focus your practice sessions on this area.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
