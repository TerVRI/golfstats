"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { cn, formatSG, calculateScoreToPar, getScoreColor, formatDate } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";
import { PlusCircle, Flag, Calendar, Target, Search, Filter, Loader2 } from "lucide-react";

interface Round {
  id: string;
  course_name: string;
  played_at: string;
  total_score: number;
  total_putts: number | null;
  fairways_hit: number | null;
  fairways_total: number | null;
  gir: number | null;
  sg_total: number | null;
  sg_off_tee: number | null;
  sg_approach: number | null;
  sg_around_green: number | null;
  sg_putting: number | null;
}

export default function RoundsPage() {
  const supabase = createClient();
  const [rounds, setRounds] = useState<Round[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  
  useEffect(() => {
    async function fetchRounds() {
      setIsLoading(true);
      setError(null);
      
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          setRounds([]);
          setIsLoading(false);
          return;
        }

        const { data, error: fetchError } = await supabase
          .from("rounds")
          .select("*")
          .eq("user_id", user.id)
          .order("played_at", { ascending: false });

        if (fetchError) throw fetchError;
        setRounds(data || []);
      } catch (err) {
        console.error("Error fetching rounds:", err);
        setError(err instanceof Error ? err.message : "Failed to load rounds");
      } finally {
        setIsLoading(false);
      }
    }

    fetchRounds();
  }, [supabase]);

  const filteredRounds = rounds.filter((round) =>
    round.course_name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const avgScore = rounds.length > 0
    ? Math.round(rounds.reduce((sum, r) => sum + r.total_score, 0) / rounds.length)
    : 0;
  const bestScore = rounds.length > 0
    ? Math.min(...rounds.map((r) => r.total_score))
    : 0;
  const avgSG = rounds.length > 0
    ? rounds.reduce((sum, r) => sum + (r.sg_total || 0), 0) / rounds.length
    : 0;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-accent-red mb-4">{error}</p>
        <Button onClick={() => window.location.reload()}>Retry</Button>
      </div>
    );
  }

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
      {rounds.length > 0 && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Rounds</p>
              <p className="text-2xl font-bold text-foreground">{rounds.length}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Avg Score</p>
              <p className="text-2xl font-bold text-foreground">{avgScore}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Best Score</p>
              <p className="text-2xl font-bold text-accent-green">{bestScore}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Avg SG</p>
              <p className={cn(
                "text-2xl font-bold",
                avgSG >= 0 ? "text-accent-green" : "text-accent-red"
              )}>
                {formatSG(avgSG)}
              </p>
            </CardContent>
          </Card>
        </div>
      )}

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
                      <p className={cn("text-xl font-bold", getScoreColor(round.total_score, 72))}>
                        {round.total_score}
                      </p>
                      <p className="text-xs text-foreground-muted">
                        {calculateScoreToPar(round.total_score, 72)}
                      </p>
                    </div>

                    {/* Putts */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">Putts</p>
                      <p className="text-xl font-bold text-foreground">{round.total_putts ?? "-"}</p>
                      <p className="text-xs text-foreground-muted">
                        {round.total_putts ? `${(round.total_putts / 18).toFixed(1)}/hole` : "-"}
                      </p>
                    </div>

                    {/* GIR */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">GIR</p>
                      <p className="text-xl font-bold text-foreground">{round.gir ?? "-"}</p>
                      <p className="text-xs text-foreground-muted">
                        {round.gir ? `${((round.gir / 18) * 100).toFixed(0)}%` : "-"}
                      </p>
                    </div>

                    {/* Strokes Gained */}
                    <div className="text-center">
                      <p className="text-xs text-foreground-muted mb-1">SG</p>
                      <p className={cn(
                        "text-xl font-bold",
                        (round.sg_total ?? 0) >= 0 ? "text-accent-green" : "text-accent-red"
                      )}>
                        {round.sg_total != null ? formatSG(round.sg_total) : "-"}
                      </p>
                      <p className="text-xs text-foreground-muted">Total</p>
                    </div>
                  </div>
                </div>

                {/* SG Breakdown Bar */}
                {round.sg_total != null && (
                  <div className="border-t border-card-border px-4 md:px-6 py-3 flex flex-wrap gap-4 text-xs">
                    <div className="flex items-center gap-1">
                      <span className="text-foreground-muted">Tee:</span>
                      <span className={cn("font-medium", (round.sg_off_tee ?? 0) >= 0 ? "text-accent-green" : "text-accent-red")}>
                        {round.sg_off_tee != null ? formatSG(round.sg_off_tee) : "-"}
                      </span>
                    </div>
                    <div className="flex items-center gap-1">
                      <span className="text-foreground-muted">Approach:</span>
                      <span className={cn("font-medium", (round.sg_approach ?? 0) >= 0 ? "text-accent-green" : "text-accent-red")}>
                        {round.sg_approach != null ? formatSG(round.sg_approach) : "-"}
                      </span>
                    </div>
                    <div className="flex items-center gap-1">
                      <span className="text-foreground-muted">Around:</span>
                      <span className={cn("font-medium", (round.sg_around_green ?? 0) >= 0 ? "text-accent-green" : "text-accent-red")}>
                        {round.sg_around_green != null ? formatSG(round.sg_around_green) : "-"}
                      </span>
                    </div>
                    <div className="flex items-center gap-1">
                      <span className="text-foreground-muted">Putting:</span>
                      <span className={cn("font-medium", (round.sg_putting ?? 0) >= 0 ? "text-accent-green" : "text-accent-red")}>
                        {round.sg_putting != null ? formatSG(round.sg_putting) : "-"}
                      </span>
                    </div>
                  </div>
                )}
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
