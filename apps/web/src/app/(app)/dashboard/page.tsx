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
  User,
  MapPin,
  Crosshair,
  Circle,
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
  LineChart,
  Line,
  AreaChart,
  Area,
  ReferenceLine,
} from "recharts";

interface Round {
  id: string;
  course_name: string;
  played_at: string;
  total_score: number;
  total_putts: number | null;
  fairways_hit: number | null;
  fairways_total: number | null;
  gir: number | null;
  course_rating: number | null;
  slope_rating: number | null;
  sg_total: number | null;
  sg_off_tee: number | null;
  sg_approach: number | null;
  sg_around_green: number | null;
  sg_putting: number | null;
}

interface Profile {
  id: string;
  full_name: string | null;
  handicap_index: number | null;
}

type TimeRange = "last5" | "last10" | "last20" | "all";

export default function DashboardPage() {
  const supabase = createClient();
  const [rounds, setRounds] = useState<Round[]>([]);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<TimeRange>("last10");

  useEffect(() => {
    async function fetchData() {
      setIsLoading(true);
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          setRounds([]);
          setIsLoading(false);
          return;
        }

        // Fetch profile
        const { data: profileData } = await supabase
          .from("profiles")
          .select("id, full_name, handicap_index")
          .eq("id", user.id)
          .single();
        
        setProfile(profileData);

        // Fetch rounds
        const limit = timeRange === "all" ? 100 : timeRange === "last20" ? 20 : timeRange === "last10" ? 10 : 5;
        const { data, error } = await supabase
          .from("rounds")
          .select("id, course_name, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, course_rating, slope_rating, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting")
          .eq("user_id", user.id)
          .order("played_at", { ascending: false })
          .limit(limit);

        if (error) throw error;
        setRounds(data || []);
      } catch (err) {
        console.error("Error fetching data:", err);
      } finally {
        setIsLoading(false);
      }
    }

    fetchData();
  }, [supabase, timeRange]);

  // Calculate stats
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

  // Calculate performance stats
  const fairwayData = rounds.filter(r => r.fairways_hit != null && r.fairways_total != null);
  const totalFairwaysHit = fairwayData.reduce((sum, r) => sum + (r.fairways_hit || 0), 0);
  const totalFairways = fairwayData.reduce((sum, r) => sum + (r.fairways_total || 0), 0);
  const fairwayPct = totalFairways > 0 ? Math.round((totalFairwaysHit / totalFairways) * 100) : 0;

  const girData = rounds.filter(r => r.gir != null);
  const totalGIR = girData.reduce((sum, r) => sum + (r.gir || 0), 0);
  const girPct = girData.length > 0 ? Math.round((totalGIR / (girData.length * 18)) * 100) : 0;

  const puttsData = rounds.filter(r => r.total_putts != null);
  const totalPutts = puttsData.reduce((sum, r) => sum + (r.total_putts || 0), 0);
  const puttsPerRound = puttsData.length > 0 ? (totalPutts / puttsData.length).toFixed(1) : "-";
  const puttsPerHole = puttsData.length > 0 ? (totalPutts / (puttsData.length * 18)).toFixed(2) : "-";

  // Calculate handicap
  const handicap = profile?.handicap_index;

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

  // Score trend data
  const scoreTrendData = [...rounds].reverse().map((round, index) => ({
    round: index + 1,
    score: round.total_score,
    date: formatDate(round.played_at),
    course: round.course_name,
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
      {/* Header with Welcome */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-accent-green/20 flex items-center justify-center">
            <User className="w-7 h-7 text-accent-green" />
          </div>
          <div>
            <p className="text-sm text-foreground-muted">Welcome back,</p>
            <h1 className="text-2xl md:text-3xl font-bold text-foreground">
              {profile?.full_name || "Golfer"}
            </h1>
          </div>
        </div>
        <div className="flex items-center gap-3">
          {/* Time Range Selector */}
          <div className="flex bg-background-secondary rounded-lg p-1">
            {(["last5", "last10", "last20", "all"] as TimeRange[]).map((range) => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={`px-3 py-1.5 text-sm rounded-md transition-colors ${
                  timeRange === range
                    ? "bg-accent-green text-white"
                    : "text-foreground-muted hover:text-foreground"
                }`}
              >
                {range === "all" ? "All" : range.replace("last", "")}
              </button>
            ))}
          </div>
          <Link href="/rounds/new">
            <Button size="lg" className="w-full sm:w-auto">
              <PlusCircle className="w-5 h-5 mr-2" />
              Log Round
            </Button>
          </Link>
        </div>
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

      {/* Quick Stats + Handicap */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
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
        {handicap !== null && handicap !== undefined && (
          <StatCard
            label="Handicap"
            value={handicap.toFixed(1)}
            icon={Flag}
            subtitle={handicap < 10 ? "Single digit!" : handicap < 18 ? "Bogey golfer" : "Keep at it!"}
            color="purple"
          />
        )}
      </div>

      {/* Score Trend Chart (NEW) */}
      {scoreTrendData.length >= 2 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <TrendingUp className="w-5 h-5" />
              Score Trend
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={scoreTrendData}>
                  <defs>
                    <linearGradient id="scoreGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                  <XAxis
                    dataKey="round"
                    tick={{ fill: "#94a3b8", fontSize: 12 }}
                    axisLine={{ stroke: "#334155" }}
                  />
                  <YAxis
                    domain={["auto", "auto"]}
                    tick={{ fill: "#94a3b8", fontSize: 12 }}
                    axisLine={{ stroke: "#334155" }}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "#1e293b",
                      border: "1px solid #334155",
                      borderRadius: "8px",
                    }}
                    formatter={(value, name) => [value, "Score"]}
                    labelFormatter={(label) => {
                      const round = scoreTrendData[label - 1];
                      return round ? `${round.course} - ${round.date}` : `Round ${label}`;
                    }}
                  />
                  <ReferenceLine y={72} stroke="#94a3b8" strokeDasharray="5 5" label={{ value: "Par", fill: "#94a3b8", fontSize: 12 }} />
                  <Area
                    type="monotone"
                    dataKey="score"
                    stroke="#10b981"
                    strokeWidth={2}
                    fill="url(#scoreGradient)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Performance Stats (NEW) */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card className="p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-blue-500/10 flex items-center justify-center">
              <MapPin className="w-5 h-5 text-blue-500" />
            </div>
            <div>
              <p className="text-sm text-foreground-muted">Fairways Hit</p>
              <p className="text-2xl font-bold text-foreground">{fairwayPct}%</p>
            </div>
          </div>
          <div className="h-2 bg-background-tertiary rounded-full overflow-hidden">
            <div
              className="h-full bg-blue-500 rounded-full transition-all"
              style={{ width: `${fairwayPct}%` }}
            />
          </div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center">
              <Crosshair className="w-5 h-5 text-green-500" />
            </div>
            <div>
              <p className="text-sm text-foreground-muted">Greens in Reg</p>
              <p className="text-2xl font-bold text-foreground">{girPct}%</p>
            </div>
          </div>
          <div className="h-2 bg-background-tertiary rounded-full overflow-hidden">
            <div
              className="h-full bg-green-500 rounded-full transition-all"
              style={{ width: `${girPct}%` }}
            />
          </div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-purple-500/10 flex items-center justify-center">
              <Circle className="w-5 h-5 text-purple-500" />
            </div>
            <div>
              <p className="text-sm text-foreground-muted">Putts / Round</p>
              <p className="text-2xl font-bold text-foreground">{puttsPerRound}</p>
            </div>
          </div>
          <p className="text-xs text-foreground-muted">{puttsPerHole} per hole</p>
        </Card>

        <Card className="p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-lg bg-amber-500/10 flex items-center justify-center">
              <Target className="w-5 h-5 text-amber-500" />
            </div>
            <div>
              <p className="text-sm text-foreground-muted">Best Score</p>
              <p className="text-2xl font-bold text-foreground">{bestRound?.total_score ?? "-"}</p>
            </div>
          </div>
          <p className="text-xs text-foreground-muted truncate">{bestRound?.course_name ?? "No rounds yet"}</p>
        </Card>
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
