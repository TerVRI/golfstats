"use client";

import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { StrokesGainedCard } from "@/components/stats";
import { cn, formatSG, formatDateShort } from "@/lib/utils";
import { Calendar, TrendingUp, TrendingDown, Minus, Target, ChevronDown } from "lucide-react";
import { useState } from "react";
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

// Demo data - last 10 rounds
const trendData = [
  { date: "2025-11-15", sg_total: -1.8, sg_tee: -0.2, sg_approach: -0.9, sg_around: -0.3, sg_putting: -0.4, score: 86 },
  { date: "2025-11-22", sg_total: -1.2, sg_tee: 0.1, sg_approach: -0.7, sg_around: -0.2, sg_putting: -0.4, score: 84 },
  { date: "2025-11-29", sg_total: -0.9, sg_tee: 0.3, sg_approach: -0.8, sg_around: -0.1, sg_putting: -0.3, score: 83 },
  { date: "2025-12-07", sg_total: -1.5, sg_tee: -0.1, sg_approach: -0.9, sg_around: -0.3, sg_putting: -0.2, score: 85 },
  { date: "2025-12-14", sg_total: 0.2, sg_tee: 0.5, sg_approach: -0.2, sg_around: 0.1, sg_putting: -0.2, score: 79 },
  { date: "2025-12-21", sg_total: 0.89, sg_tee: 0.67, sg_approach: 0.12, sg_around: 0.44, sg_putting: -0.34, score: 79 },
  { date: "2025-12-28", sg_total: -0.56, sg_tee: 0.22, sg_approach: -0.45, sg_around: -0.11, sg_putting: -0.22, score: 80 },
  { date: "2026-01-03", sg_total: -2.15, sg_tee: -0.45, sg_approach: -0.89, sg_around: -0.31, sg_putting: -0.50, score: 85 },
  { date: "2026-01-07", sg_total: 1.22, sg_tee: 0.78, sg_approach: 0.34, sg_around: 0.56, sg_putting: -0.46, score: 78 },
  { date: "2026-01-10", sg_total: -0.84, sg_tee: 0.52, sg_approach: -1.12, sg_around: -0.24, sg_putting: 0.00, score: 82 },
];

// Calculate averages
const calculateAverage = (data: typeof trendData, key: keyof typeof trendData[0]) => {
  const values = data.map((d) => d[key] as number);
  return values.reduce((sum, v) => sum + v, 0) / values.length;
};

const averages = {
  sg_total: calculateAverage(trendData, "sg_total"),
  sg_tee: calculateAverage(trendData, "sg_tee"),
  sg_approach: calculateAverage(trendData, "sg_approach"),
  sg_around: calculateAverage(trendData, "sg_around"),
  sg_putting: calculateAverage(trendData, "sg_putting"),
  score: calculateAverage(trendData, "score"),
};

// Calculate trends (last 5 vs previous 5)
const calculateTrend = (data: typeof trendData, key: keyof typeof trendData[0]) => {
  const recent = data.slice(-5).map((d) => d[key] as number);
  const previous = data.slice(-10, -5).map((d) => d[key] as number);
  const recentAvg = recent.reduce((sum, v) => sum + v, 0) / recent.length;
  const previousAvg = previous.reduce((sum, v) => sum + v, 0) / previous.length;
  return recentAvg - previousAvg;
};

const trends = {
  sg_total: calculateTrend(trendData, "sg_total"),
  sg_tee: calculateTrend(trendData, "sg_tee"),
  sg_approach: calculateTrend(trendData, "sg_approach"),
  sg_around: calculateTrend(trendData, "sg_around"),
  sg_putting: calculateTrend(trendData, "sg_putting"),
};

type TimeRange = "last5" | "last10" | "all";

export default function TrendsPage() {
  const [timeRange, setTimeRange] = useState<TimeRange>("last10");

  const filteredData = timeRange === "last5" 
    ? trendData.slice(-5) 
    : timeRange === "last10" 
    ? trendData.slice(-10)
    : trendData;

  const chartData = filteredData.map((d) => ({
    ...d,
    date: formatDateShort(d.date),
  }));

  const TrendIndicator = ({ value }: { value: number }) => {
    if (value > 0.1) return <TrendingUp className="w-4 h-4 text-accent-green" />;
    if (value < -0.1) return <TrendingDown className="w-4 h-4 text-accent-red" />;
    return <Minus className="w-4 h-4 text-foreground-muted" />;
  };

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
          value={averages.sg_tee}
          label="Avg SG: Tee"
          showTrend
          trend={trends.sg_tee}
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
          value={averages.sg_around}
          label="Avg SG: Around"
          showTrend
          trend={trends.sg_around}
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
                  formatter={(value: number) => [formatSG(value), "Total SG"]}
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
                  formatter={(value: number, name: string) => {
                    const labels: Record<string, string> = {
                      sg_tee: "Off Tee",
                      sg_approach: "Approach",
                      sg_around: "Around Green",
                      sg_putting: "Putting",
                    };
                    return [formatSG(value), labels[name] || name];
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
                  domain={[75, 90]}
                  reversed
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "#1e293b",
                    border: "1px solid #334155",
                    borderRadius: "8px",
                  }}
                  formatter={(value: number) => [value, "Score"]}
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
                    sg_tee: "Off the Tee",
                    sg_approach: "Approach",
                    sg_around: "Around the Green",
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
                    sg_tee: "Off the Tee",
                    sg_approach: "Approach",
                    sg_around: "Around the Green",
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
      <Card className="border-accent-amber/20">
        <CardContent className="py-6">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent-amber/10 flex items-center justify-center flex-shrink-0">
              <Target className="w-6 h-6 text-accent-amber" />
            </div>
            <div>
              <h3 className="font-semibold text-foreground mb-1">Practice Recommendation</h3>
              <p className="text-foreground-muted text-sm">
                Based on your trends, your <span className="text-accent-red font-medium">approach shots</span> are 
                your biggest opportunity for improvement. Focus on iron play from 100-150 yards. 
                Your <span className="text-accent-green font-medium">off the tee</span> game has been improving - 
                keep up the good work on the driving range!
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

