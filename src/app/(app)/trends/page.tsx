"use client";

import { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { StrokesGainedCard } from "@/components/stats";
import { cn, formatSG, formatDateShort } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import { Calendar, TrendingUp, TrendingDown, Minus, Target, Loader2, PlusCircle } from "lucide-react";
import Link from "next/link";
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  AreaChart,
  Area,
  ReferenceLine,
} from "recharts";

interface Round {
  id: string;
  played_at: string;
  total_score: number;
  sg_total: number | null;
  sg_off_tee: number | null;
  sg_approach: number | null;
  sg_around_green: number | null;
  sg_putting: number | null;
}

type TimeRange = "last5" | "last10" | "all";

export default function TrendsPage() {
  const supabase = createClient();
  const [rounds, setRounds] = useState<Round[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<TimeRange>("last10");

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
          .select("id, played_at, total_score, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting")
          .eq("user_id", user.id)
          .order("played_at", { ascending: true });

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

  // Filter data based on time range
  const filteredRounds = timeRange === "last5"
    ? rounds.slice(-5)
    : timeRange === "last10"
    ? rounds.slice(-10)
    : rounds;

  // Calculate averages
  const calculateAverage = (data: Round[], key: keyof Round) => {
    if (data.length === 0) return 0;
    const values = data.map((d) => (d[key] as number) || 0);
    return values.reduce((sum, v) => sum + v, 0) / values.length;
  };

  const averages = {
    sg_total: calculateAverage(filteredRounds, "sg_total"),
    sg_off_tee: calculateAverage(filteredRounds, "sg_off_tee"),
    sg_approach: calculateAverage(filteredRounds, "sg_approach"),
    sg_around_green: calculateAverage(filteredRounds, "sg_around_green"),
    sg_putting: calculateAverage(filteredRounds, "sg_putting"),
    score: calculateAverage(filteredRounds, "total_score"),
  };

  // Calculate trends (last 5 vs previous 5)
  const calculateTrend = (data: Round[], key: keyof Round) => {
    if (data.length < 6) return 0;
    const recent = data.slice(-5).map((d) => (d[key] as number) || 0);
    const previous = data.slice(-10, -5).map((d) => (d[key] as number) || 0);
    if (previous.length === 0) return 0;
    const recentAvg = recent.reduce((sum, v) => sum + v, 0) / recent.length;
    const previousAvg = previous.reduce((sum, v) => sum + v, 0) / previous.length;
    return recentAvg - previousAvg;
  };

  const trends = {
    sg_total: calculateTrend(rounds, "sg_total"),
    sg_off_tee: calculateTrend(rounds, "sg_off_tee"),
    sg_approach: calculateTrend(rounds, "sg_approach"),
    sg_around_green: calculateTrend(rounds, "sg_around_green"),
    sg_putting: calculateTrend(rounds, "sg_putting"),
  };

  // Prepare chart data
  const chartData = filteredRounds.map((d) => ({
    date: formatDateShort(d.played_at),
    sg_total: d.sg_total || 0,
    sg_tee: d.sg_off_tee || 0,
    sg_approach: d.sg_approach || 0,
    sg_around: d.sg_around_green || 0,
    sg_putting: d.sg_putting || 0,
    score: d.total_score,
  }));

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
      <div className="space-y-6 animate-fade-in">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Trends</h1>
          <p className="text-foreground-muted mt-1">
            Track your improvement over time
          </p>
        </div>

        <Card>
          <CardContent className="py-16 text-center">
            <TrendingUp className="w-16 h-16 text-foreground-muted mx-auto mb-6" />
            <h2 className="text-2xl font-bold text-foreground mb-2">No Data Yet</h2>
            <p className="text-foreground-muted mb-6 max-w-md mx-auto">
              Log some rounds to start seeing your trends and track your improvement over time.
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

  // Need at least 2 rounds for trends
  if (rounds.length < 2) {
    return (
      <div className="space-y-6 animate-fade-in">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Trends</h1>
          <p className="text-foreground-muted mt-1">
            Track your improvement over time
          </p>
        </div>

        <Card>
          <CardContent className="py-16 text-center">
            <TrendingUp className="w-16 h-16 text-foreground-muted mx-auto mb-6" />
            <h2 className="text-2xl font-bold text-foreground mb-2">More Rounds Needed</h2>
            <p className="text-foreground-muted mb-6 max-w-md mx-auto">
              Log at least 2 rounds to start seeing your trends. You have {rounds.length} round{rounds.length !== 1 ? "s" : ""} logged.
            </p>
            <Link href="/rounds/new">
              <Button size="lg">
                <PlusCircle className="w-5 h-5 mr-2" />
                Log Another Round
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Trends</h1>
          <p className="text-foreground-muted mt-1">
            Track your improvement over time
          </p>
        </div>
        
        {/* Time Range Selector */}
        <div className="flex gap-2">
          {[
            { value: "last5", label: "Last 5" },
            { value: "last10", label: "Last 10" },
            { value: "all", label: "All Time" },
          ].map((option) => (
            <Button
              key={option.value}
              variant={timeRange === option.value ? "primary" : "secondary"}
              size="sm"
              onClick={() => setTimeRange(option.value as TimeRange)}
            >
              {option.label}
            </Button>
          ))}
        </div>
      </div>

      {/* Summary Stats with Trends */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <StrokesGainedCard
          category="total"
          value={averages.sg_total}
          label="Avg Total SG"
          showTrend
          trend={trends.sg_total}
        />
        <StrokesGainedCard
          category="off_tee"
          value={averages.sg_off_tee}
          label="Avg SG: Tee"
          showTrend
          trend={trends.sg_off_tee}
        />
        <StrokesGainedCard
          category="approach"
          value={averages.sg_approach}
          label="Avg SG: Approach"
          showTrend
          trend={trends.sg_approach}
        />
        <StrokesGainedCard
          category="around_green"
          value={averages.sg_around_green}
          label="Avg SG: Around"
          showTrend
          trend={trends.sg_around_green}
        />
        <StrokesGainedCard
          category="putting"
          value={averages.sg_putting}
          label="Avg SG: Putting"
          showTrend
          trend={trends.sg_putting}
        />
      </div>

      {/* Total SG Over Time */}
      <Card>
        <CardHeader>
          <CardTitle>Total Strokes Gained Over Time</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="sgGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis
                  dataKey="date"
                  tick={{ fill: "#94a3b8", fontSize: 11 }}
                  axisLine={{ stroke: "#334155" }}
                />
                <YAxis
                  tick={{ fill: "#94a3b8", fontSize: 11 }}
                  axisLine={{ stroke: "#334155" }}
                  domain={[-3, 2]}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "#1e293b",
                    border: "1px solid #334155",
                    borderRadius: "8px",
                  }}
                  formatter={(value) => [formatSG(value as number), "Total SG"]}
                />
                <ReferenceLine y={0} stroke="#475569" strokeDasharray="3 3" />
                <Area
                  type="monotone"
                  dataKey="sg_total"
                  stroke="#10b981"
                  fill="url(#sgGradient)"
                  strokeWidth={2}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      {/* SG by Category Over Time */}
      <Card>
        <CardHeader>
          <CardTitle>Strokes Gained by Category</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="h-[350px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis
                  dataKey="date"
                  tick={{ fill: "#94a3b8", fontSize: 11 }}
                  axisLine={{ stroke: "#334155" }}
                />
                <YAxis
                  tick={{ fill: "#94a3b8", fontSize: 11 }}
                  axisLine={{ stroke: "#334155" }}
                  domain={[-1.5, 1]}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "#1e293b",
                    border: "1px solid #334155",
                    borderRadius: "8px",
                  }}
                  formatter={(value, name) => {
                    const labels: Record<string, string> = {
                      sg_tee: "Off Tee",
                      sg_approach: "Approach",
                      sg_around: "Around Green",
                      sg_putting: "Putting",
                    };
                    return [formatSG(value as number), labels[name as string] || name];
                  }}
                />
                <Legend
                  formatter={(value) => {
                    const labels: Record<string, string> = {
                      sg_tee: "Off Tee",
                      sg_approach: "Approach",
                      sg_around: "Around Green",
                      sg_putting: "Putting",
                    };
                    return labels[value] || value;
                  }}
                />
                <ReferenceLine y={0} stroke="#475569" strokeDasharray="3 3" />
                <Line
                  type="monotone"
                  dataKey="sg_tee"
                  stroke="#3b82f6"
                  strokeWidth={2}
                  dot={{ r: 4 }}
                />
                <Line
                  type="monotone"
                  dataKey="sg_approach"
                  stroke="#a855f7"
                  strokeWidth={2}
                  dot={{ r: 4 }}
                />
                <Line
                  type="monotone"
                  dataKey="sg_around"
                  stroke="#f59e0b"
                  strokeWidth={2}
                  dot={{ r: 4 }}
                />
                <Line
                  type="monotone"
                  dataKey="sg_putting"
                  stroke="#10b981"
                  strokeWidth={2}
                  dot={{ r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      {/* Score Trend */}
      <Card>
        <CardHeader>
          <CardTitle>Score Trend</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="h-[250px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis
                  dataKey="date"
                  tick={{ fill: "#94a3b8", fontSize: 11 }}
                  axisLine={{ stroke: "#334155" }}
                />
                <YAxis
                  tick={{ fill: "#94a3b8", fontSize: 11 }}
                  axisLine={{ stroke: "#334155" }}
                  domain={["dataMin - 5", "dataMax + 5"]}
                  reversed
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "#1e293b",
                    border: "1px solid #334155",
                    borderRadius: "8px",
                  }}
                  formatter={(value) => [value as number, "Score"]}
                />
                <ReferenceLine y={averages.score} stroke="#f59e0b" strokeDasharray="3 3" label={{ value: `Avg: ${averages.score.toFixed(1)}`, fill: "#f59e0b", fontSize: 11 }} />
                <Line
                  type="monotone"
                  dataKey="score"
                  stroke="#f43f5e"
                  strokeWidth={2}
                  dot={{ fill: "#f43f5e", r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
          <p className="text-sm text-foreground-muted text-center mt-4">
            Lower scores are better (chart is inverted for clarity)
          </p>
        </CardContent>
      </Card>

      {/* Insights */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card className="bg-gradient-to-br from-accent-green/5 to-background-secondary">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-accent-green" />
              Improving
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {Object.entries(trends)
                .filter(([_, value]) => value > 0.1)
                .sort(([_, a], [__, b]) => b - a)
                .map(([key, value]) => {
                  const labels: Record<string, string> = {
                    sg_total: "Total",
                    sg_off_tee: "Off the Tee",
                    sg_approach: "Approach",
                    sg_around_green: "Around the Green",
                    sg_putting: "Putting",
                  };
                  return (
                    <div key={key} className="flex items-center justify-between p-3 rounded-lg bg-background-secondary">
                      <span className="text-foreground">{labels[key]}</span>
                      <span className="text-accent-green font-medium">+{value.toFixed(2)}</span>
                    </div>
                  );
                })}
              {Object.entries(trends).filter(([_, value]) => value > 0.1).length === 0 && (
                <p className="text-foreground-muted text-center py-4">
                  Keep practicing! Improvements will show here.
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        <Card className="bg-gradient-to-br from-accent-red/5 to-background-secondary">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingDown className="w-5 h-5 text-accent-red" />
              Needs Work
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {Object.entries(trends)
                .filter(([_, value]) => value < -0.1)
                .sort(([_, a], [__, b]) => a - b)
                .map(([key, value]) => {
                  const labels: Record<string, string> = {
                    sg_total: "Total",
                    sg_off_tee: "Off the Tee",
                    sg_approach: "Approach",
                    sg_around_green: "Around the Green",
                    sg_putting: "Putting",
                  };
                  return (
                    <div key={key} className="flex items-center justify-between p-3 rounded-lg bg-background-secondary">
                      <span className="text-foreground">{labels[key]}</span>
                      <span className="text-accent-red font-medium">{value.toFixed(2)}</span>
                    </div>
                  );
                })}
              {Object.entries(trends).filter(([_, value]) => value < -0.1).length === 0 && (
                <p className="text-foreground-muted text-center py-4">
                  Great job! No declining areas.
                </p>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Recommendation */}
      {rounds.length >= 5 && (
        <Card className="border-accent-amber/20">
          <CardContent className="py-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-xl bg-accent-amber/10 flex items-center justify-center flex-shrink-0">
                <Target className="w-6 h-6 text-accent-amber" />
              </div>
              <div>
                <h3 className="font-semibold text-foreground mb-1">Practice Recommendation</h3>
                <p className="text-foreground-muted text-sm">
                  {(() => {
                    const weakest = Object.entries({
                      "approach shots": averages.sg_approach,
                      "off the tee": averages.sg_off_tee,
                      "around the green": averages.sg_around_green,
                      "putting": averages.sg_putting,
                    }).reduce((worst, [name, val]) => val < worst[1] ? [name, val] : worst, ["", 0]);
                    
                    const strongest = Object.entries({
                      "off the tee": averages.sg_off_tee,
                      "approach shots": averages.sg_approach,
                      "around the green": averages.sg_around_green,
                      "putting": averages.sg_putting,
                    }).reduce((best, [name, val]) => val > best[1] ? [name, val] : best, ["", -10]);

                    return (
                      <>
                        Based on your trends, your <span className="text-accent-red font-medium">{weakest[0]}</span> are
                        your biggest opportunity for improvement. Focus your practice sessions on this area.
                        {strongest[1] > 0 && (
                          <> Your <span className="text-accent-green font-medium">{strongest[0]}</span> game is a strength - keep it up!</>
                        )}
                      </>
                    );
                  })()}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
