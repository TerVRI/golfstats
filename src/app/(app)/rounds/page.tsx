"use client";

import Link from "next/link";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { cn, formatSG, calculateScoreToPar, getScoreColor, formatDate } from "@/lib/utils";
import { PlusCircle, Flag, Calendar, Target, Search, Filter } from "lucide-react";
import { useState } from "react";

// Demo data
const demoRounds = [
  {
    id: "1",
    course_name: "Pebble Beach Golf Links",
    played_at: "2026-01-10",
    total_score: 82,
    total_par: 72,
    total_putts: 32,
    fairways_hit: 8,
    fairways_total: 14,
    gir: 9,
    sg_total: -0.84,
    sg_off_tee: 0.52,
    sg_approach: -1.12,
    sg_around_green: -0.24,
    sg_putting: 0.00,
  },
  {
    id: "2",
    course_name: "TPC Sawgrass",
    played_at: "2026-01-07",
    total_score: 78,
    total_par: 72,
    total_putts: 29,
    fairways_hit: 10,
    fairways_total: 14,
    gir: 12,
    sg_total: 1.22,
    sg_off_tee: 0.78,
    sg_approach: 0.34,
    sg_around_green: 0.56,
    sg_putting: -0.46,
  },
  {
    id: "3",
    course_name: "Augusta National",
    played_at: "2026-01-03",
    total_score: 85,
    total_par: 72,
    total_putts: 34,
    fairways_hit: 6,
    fairways_total: 14,
    gir: 7,
    sg_total: -2.15,
    sg_off_tee: -0.45,
    sg_approach: -0.89,
    sg_around_green: -0.31,
    sg_putting: -0.50,
  },
  {
    id: "4",
    course_name: "St Andrews - Old Course",
    played_at: "2025-12-28",
    total_score: 80,
    total_par: 72,
    total_putts: 31,
    fairways_hit: 9,
    fairways_total: 14,
    gir: 10,
    sg_total: -0.56,
    sg_off_tee: 0.22,
    sg_approach: -0.45,
    sg_around_green: -0.11,
    sg_putting: -0.22,
  },
  {
    id: "5",
    course_name: "Cypress Point",
    played_at: "2025-12-21",
    total_score: 79,
    total_par: 72,
    total_putts: 30,
    fairways_hit: 11,
    fairways_total: 14,
    gir: 11,
    sg_total: 0.89,
    sg_off_tee: 0.67,
    sg_approach: 0.12,
    sg_around_green: 0.44,
    sg_putting: -0.34,
  },
];

export default function RoundsPage() {
  const [searchQuery, setSearchQuery] = useState("");
  
  const filteredRounds = demoRounds.filter((round) =>
    round.course_name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Round History</h1>
          <p className="text-foreground-muted mt-1">
            View and analyze all your rounds
          </p>
        </div>
        <Link href="/rounds/new">
          <Button size="lg" className="w-full sm:w-auto">
            <PlusCircle className="w-5 h-5 mr-2" />
            Log New Round
          </Button>
        </Link>
      </div>

      {/* Search and Filter */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground-muted" />
          <input
            type="text"
            placeholder="Search courses..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 rounded-lg bg-background-secondary border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-blue"
          />
        </div>
        <Button variant="secondary" className="flex items-center gap-2">
          <Filter className="w-4 h-4" />
          Filter
        </Button>
      </div>

      {/* Stats Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Rounds</p>
            <p className="text-2xl font-bold text-foreground">{demoRounds.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Avg Score</p>
            <p className="text-2xl font-bold text-foreground">
              {Math.round(demoRounds.reduce((sum, r) => sum + r.total_score, 0) / demoRounds.length)}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Best Score</p>
            <p className="text-2xl font-bold text-accent-green">
              {Math.min(...demoRounds.map((r) => r.total_score))}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-sm text-foreground-muted mb-1">Avg SG</p>
            <p className={cn(
              "text-2xl font-bold",
              demoRounds.reduce((sum, r) => sum + r.sg_total, 0) / demoRounds.length >= 0
                ? "text-accent-green"
                : "text-accent-red"
            )}>
              {formatSG(demoRounds.reduce((sum, r) => sum + r.sg_total, 0) / demoRounds.length)}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Rounds List */}
      <div className="space-y-4">
        {filteredRounds.map((round) => (
          <Link key={round.id} href={`/rounds/${round.id}`}>
            <Card hover className="mb-4">
              <CardContent className="p-0">
                <div className="flex flex-col md:flex-row md:items-center justify-between p-4 md:p-6">
                  {/* Course Info */}
                  <div className="flex items-center gap-4 mb-4 md:mb-0">
                    <div className="w-12 h-12 rounded-xl bg-accent-green/10 flex items-center justify-center flex-shrink-0">
                      <Flag className="w-6 h-6 text-accent-green" />
                    </div>
                    <div>
                      <h3 className="font-semibold text-foreground">{round.course_name}</h3>
                      <div className="flex items-center gap-2 text-sm text-foreground-muted">
                        <Calendar className="w-4 h-4" />
                        {formatDate(round.played_at)}
                      </div>
                    </div>
                  </div>

                  {/* Stats Grid */}
                  <div className="grid grid-cols-4 gap-4 md:gap-8">
                    {/* Score */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">Score</p>
                      <p className={cn("text-xl font-bold", getScoreColor(round.total_score, round.total_par))}>
                        {round.total_score}
                      </p>
                      <p className="text-xs text-foreground-muted">
                        {calculateScoreToPar(round.total_score, round.total_par)}
                      </p>
                    </div>

                    {/* Putts */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">Putts</p>
                      <p className="text-xl font-bold text-foreground">{round.total_putts}</p>
                      <p className="text-xs text-foreground-muted">
                        {(round.total_putts / 18).toFixed(1)}/hole
                      </p>
                    </div>

                    {/* GIR */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">GIR</p>
                      <p className="text-xl font-bold text-foreground">{round.gir}</p>
                      <p className="text-xs text-foreground-muted">
                        {((round.gir / 18) * 100).toFixed(0)}%
                      </p>
                    </div>

                    {/* Strokes Gained */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">SG</p>
                      <p className={cn(
                        "text-xl font-bold",
                        round.sg_total >= 0 ? "text-accent-green" : "text-accent-red"
                      )}>
                        {formatSG(round.sg_total)}
                      </p>
                      <p className="text-xs text-foreground-muted">Total</p>
                    </div>
                  </div>
                </div>

                {/* SG Breakdown Bar */}
                <div className="border-t border-card-border px-4 md:px-6 py-3 flex flex-wrap gap-4 text-xs">
                  <div className="flex items-center gap-1">
                    <span className="text-foreground-muted">Tee:</span>
                    <span className={cn("font-medium", round.sg_off_tee >= 0 ? "text-accent-green" : "text-accent-red")}>
                      {formatSG(round.sg_off_tee)}
                    </span>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-foreground-muted">Approach:</span>
                    <span className={cn("font-medium", round.sg_approach >= 0 ? "text-accent-green" : "text-accent-red")}>
                      {formatSG(round.sg_approach)}
                    </span>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-foreground-muted">Around:</span>
                    <span className={cn("font-medium", round.sg_around_green >= 0 ? "text-accent-green" : "text-accent-red")}>
                      {formatSG(round.sg_around_green)}
                    </span>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-foreground-muted">Putting:</span>
                    <span className={cn("font-medium", round.sg_putting >= 0 ? "text-accent-green" : "text-accent-red")}>
                      {formatSG(round.sg_putting)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {filteredRounds.length === 0 && (
        <Card>
          <CardContent className="py-12 text-center">
            <Target className="w-12 h-12 text-foreground-muted mx-auto mb-4" />
            <h3 className="text-lg font-medium text-foreground mb-2">No rounds found</h3>
            <p className="text-foreground-muted mb-4">
              {searchQuery
                ? "Try adjusting your search query"
                : "Start tracking your rounds to see your stats"}
            </p>
            {!searchQuery && (
              <Link href="/rounds/new">
                <Button>
                  <PlusCircle className="w-4 h-4 mr-2" />
                  Log Your First Round
                </Button>
              </Link>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}

