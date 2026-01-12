"use client";

import { StrokesGainedCard, StatCard } from "@/components/stats";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { formatSG, calculateScoreToPar, getScoreColor, formatDate } from "@/lib/utils";
import Link from "next/link";
import {
  PlusCircle,
  Trophy,
  Target,
  Flag,
  CircleDot,
  TrendingUp,
  Calendar,
  ArrowRight,
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

// Demo data - in production this would come from the database
const demoStrokesGained = {
  sg_total: -1.24,
  sg_off_tee: 0.42,
  sg_approach: -0.89,
  sg_around_green: -0.31,
  sg_putting: -0.46,
};

const demoRecentRounds = [
  { id: "1", course_name: "Pebble Beach", played_at: "2026-01-10", total_score: 82, par: 72, sg_total: -0.84 },
  { id: "2", course_name: "TPC Sawgrass", played_at: "2026-01-07", total_score: 78, par: 72, sg_total: 1.22 },
  { id: "3", course_name: "Augusta National", played_at: "2026-01-03", total_score: 85, par: 72, sg_total: -2.15 },
  { id: "4", course_name: "St Andrews", played_at: "2025-12-28", total_score: 80, par: 72, sg_total: -0.56 },
];

const radarData = [
  { category: "Off Tee", value: demoStrokesGained.sg_off_tee + 2, fullMark: 4 },
  { category: "Approach", value: demoStrokesGained.sg_approach + 2, fullMark: 4 },
  { category: "Around Green", value: demoStrokesGained.sg_around_green + 2, fullMark: 4 },
  { category: "Putting", value: demoStrokesGained.sg_putting + 2, fullMark: 4 },
];

const sgBreakdownData = [
  { name: "Off Tee", value: demoStrokesGained.sg_off_tee },
  { name: "Approach", value: demoStrokesGained.sg_approach },
  { name: "Around Green", value: demoStrokesGained.sg_around_green },
  { name: "Putting", value: demoStrokesGained.sg_putting },
];

export default function DashboardPage() {
  const roundsCount = demoRecentRounds.length;
  const avgScore = Math.round(
    demoRecentRounds.reduce((sum, r) => sum + r.total_score, 0) / roundsCount
  );

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
          value={demoStrokesGained.sg_total}
          label="Total SG"
          description="Per round average"
          className="lg:col-span-1"
        />
        <StrokesGainedCard
          category="off_tee"
          value={demoStrokesGained.sg_off_tee}
          label="SG: Off the Tee"
        />
        <StrokesGainedCard
          category="approach"
          value={demoStrokesGained.sg_approach}
          label="SG: Approach"
        />
        <StrokesGainedCard
          category="around_green"
          value={demoStrokesGained.sg_around_green}
          label="SG: Around Green"
        />
        <StrokesGainedCard
          category="putting"
          value={demoStrokesGained.sg_putting}
          label="SG: Putting"
        />
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          label="Rounds Played"
          value={roundsCount}
          icon={Calendar}
          subtitle="This month"
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
          value={Math.min(...demoRecentRounds.map(r => r.total_score))}
          icon={Target}
          subtitle="TPC Sawgrass"
          color="green"
        />
        <StatCard
          label="Improvement"
          value="+2.1"
          icon={TrendingUp}
          subtitle="Strokes gained"
          color="green"
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
                    formatter={(value: number) => [formatSG(value), "SG"]}
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
            {demoRecentRounds.map((round) => (
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
                    <p className={`text-lg font-bold ${getScoreColor(round.total_score, round.par)}`}>
                      {round.total_score}
                    </p>
                    <p className="text-xs text-foreground-muted">
                      {calculateScoreToPar(round.total_score, round.par)}
                    </p>
                  </div>
                  <div className="text-right min-w-[60px]">
                    <p className={`text-lg font-bold ${round.sg_total >= 0 ? "text-accent-green" : "text-accent-red"}`}>
                      {formatSG(round.sg_total)}
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
      <Card className="bg-gradient-to-br from-background-secondary to-background-tertiary border-accent-amber/20">
        <CardContent className="py-6">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent-amber/10 flex items-center justify-center flex-shrink-0">
              <Target className="w-6 h-6 text-accent-amber" />
            </div>
            <div>
              <h3 className="font-semibold text-foreground mb-1">Focus Area: Approach Shots</h3>
              <p className="text-foreground-muted text-sm">
                Your approach shots are costing you <span className="text-accent-red font-medium">0.89 strokes per round</span>. 
                This is your biggest opportunity for improvement. Consider working on distance control with your irons 
                and practicing from 100-150 yards.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

