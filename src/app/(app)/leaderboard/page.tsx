"use client";

import { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent, Button } from "@/components/ui";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";
import {
  Trophy,
  Medal,
  Target,
  TrendingUp,
  User,
  Loader2,
  Crown,
  Award,
} from "lucide-react";

interface LeaderboardEntry {
  id: string;
  name: string | null;
  email: string;
  handicap: number | null;
  avg_score: number;
  best_score: number;
  rounds_count: number;
  avg_sg: number;
}

type LeaderboardType = "handicap" | "avg_score" | "best_score" | "strokes_gained";

export default function LeaderboardPage() {
  const supabase = createClient();
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [leaderboardType, setLeaderboardType] = useState<LeaderboardType>("handicap");
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  useEffect(() => {
    loadLeaderboard();
  }, []);

  async function loadLeaderboard() {
    setIsLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      setCurrentUserId(user?.id || null);

      // Get public profiles with their round stats
      const { data: profiles, error: profilesError } = await supabase
        .from("profiles")
        .select("id, name, email, handicap, is_public")
        .eq("is_public", true);

      if (profilesError) throw profilesError;

      // For each profile, get their round stats
      const entries: LeaderboardEntry[] = [];
      
      for (const profile of profiles || []) {
        const { data: rounds } = await supabase
          .from("rounds")
          .select("total_score, sg_total")
          .eq("user_id", profile.id);

        if (rounds && rounds.length > 0) {
          const avgScore = rounds.reduce((sum, r) => sum + r.total_score, 0) / rounds.length;
          const bestScore = Math.min(...rounds.map(r => r.total_score));
          const avgSG = rounds.reduce((sum, r) => sum + (r.sg_total || 0), 0) / rounds.length;

          entries.push({
            id: profile.id,
            name: profile.name,
            email: profile.email,
            handicap: profile.handicap,
            avg_score: Math.round(avgScore * 10) / 10,
            best_score: bestScore,
            rounds_count: rounds.length,
            avg_sg: Math.round(avgSG * 100) / 100,
          });
        }
      }

      // Also add current user if they have rounds (even if not public)
      if (user) {
        const existingEntry = entries.find(e => e.id === user.id);
        if (!existingEntry) {
          const { data: userProfile } = await supabase
            .from("profiles")
            .select("id, name, email, handicap")
            .eq("id", user.id)
            .single();

          const { data: userRounds } = await supabase
            .from("rounds")
            .select("total_score, sg_total")
            .eq("user_id", user.id);

          if (userProfile && userRounds && userRounds.length > 0) {
            const avgScore = userRounds.reduce((sum, r) => sum + r.total_score, 0) / userRounds.length;
            const bestScore = Math.min(...userRounds.map(r => r.total_score));
            const avgSG = userRounds.reduce((sum, r) => sum + (r.sg_total || 0), 0) / userRounds.length;

            entries.push({
              id: userProfile.id,
              name: userProfile.name,
              email: userProfile.email,
              handicap: userProfile.handicap,
              avg_score: Math.round(avgScore * 10) / 10,
              best_score: bestScore,
              rounds_count: userRounds.length,
              avg_sg: Math.round(avgSG * 100) / 100,
            });
          }
        }
      }

      setLeaderboard(entries);
    } catch (err) {
      console.error("Error loading leaderboard:", err);
    } finally {
      setIsLoading(false);
    }
  }

  const getSortedLeaderboard = () => {
    const sorted = [...leaderboard];
    switch (leaderboardType) {
      case "handicap":
        return sorted
          .filter(e => e.handicap !== null)
          .sort((a, b) => (a.handicap || 99) - (b.handicap || 99));
      case "avg_score":
        return sorted.sort((a, b) => a.avg_score - b.avg_score);
      case "best_score":
        return sorted.sort((a, b) => a.best_score - b.best_score);
      case "strokes_gained":
        return sorted.sort((a, b) => b.avg_sg - a.avg_sg);
      default:
        return sorted;
    }
  };

  const sortedLeaderboard = getSortedLeaderboard();

  const getRankIcon = (rank: number) => {
    if (rank === 1) return <Crown className="w-5 h-5 text-yellow-400" />;
    if (rank === 2) return <Medal className="w-5 h-5 text-gray-400" />;
    if (rank === 3) return <Medal className="w-5 h-5 text-amber-600" />;
    return <span className="text-foreground-muted font-medium">{rank}</span>;
  };

  const getDisplayValue = (entry: LeaderboardEntry) => {
    switch (leaderboardType) {
      case "handicap":
        return entry.handicap?.toFixed(1) ?? "—";
      case "avg_score":
        return entry.avg_score.toFixed(1);
      case "best_score":
        return entry.best_score.toString();
      case "strokes_gained":
        return entry.avg_sg >= 0 ? `+${entry.avg_sg.toFixed(2)}` : entry.avg_sg.toFixed(2);
      default:
        return "—";
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Leaderboard</h1>
          <p className="text-foreground-muted mt-1">
            See how you stack up against other golfers
          </p>
        </div>
      </div>

      {/* Leaderboard Type Selector */}
      <div className="flex flex-wrap gap-2">
        {[
          { value: "handicap", label: "Handicap", icon: Award },
          { value: "avg_score", label: "Avg Score", icon: Target },
          { value: "best_score", label: "Best Score", icon: Trophy },
          { value: "strokes_gained", label: "Strokes Gained", icon: TrendingUp },
        ].map((type) => {
          const Icon = type.icon;
          return (
            <Button
              key={type.value}
              variant={leaderboardType === type.value ? "primary" : "secondary"}
              size="sm"
              onClick={() => setLeaderboardType(type.value as LeaderboardType)}
            >
              <Icon className="w-4 h-4 mr-2" />
              {type.label}
            </Button>
          );
        })}
      </div>

      {/* Leaderboard Table */}
      {sortedLeaderboard.length > 0 ? (
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-card-border">
                    <th className="p-4 text-left text-foreground-muted font-medium w-16">Rank</th>
                    <th className="p-4 text-left text-foreground-muted font-medium">Player</th>
                    <th className="p-4 text-center text-foreground-muted font-medium">Rounds</th>
                    <th className="p-4 text-center text-foreground-muted font-medium">Avg Score</th>
                    <th className="p-4 text-center text-foreground-muted font-medium">Best</th>
                    <th className="p-4 text-right text-foreground-muted font-medium">
                      {leaderboardType === "handicap" ? "Handicap" :
                       leaderboardType === "avg_score" ? "Avg Score" :
                       leaderboardType === "best_score" ? "Best Score" : "Avg SG"}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {sortedLeaderboard.map((entry, index) => {
                    const isCurrentUser = entry.id === currentUserId;
                    return (
                      <tr
                        key={entry.id}
                        className={cn(
                          "border-b border-card-border last:border-0 transition-colors",
                          isCurrentUser && "bg-accent-green/5"
                        )}
                      >
                        <td className="p-4">
                          <div className="w-8 h-8 flex items-center justify-center">
                            {getRankIcon(index + 1)}
                          </div>
                        </td>
                        <td className="p-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-accent-green/10 flex items-center justify-center">
                              <User className="w-5 h-5 text-accent-green" />
                            </div>
                            <div>
                              <p className={cn(
                                "font-medium",
                                isCurrentUser ? "text-accent-green" : "text-foreground"
                              )}>
                                {entry.name || "Anonymous"}
                                {isCurrentUser && " (You)"}
                              </p>
                              {entry.handicap && (
                                <p className="text-xs text-foreground-muted">
                                  HCP: {entry.handicap.toFixed(1)}
                                </p>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="p-4 text-center text-foreground-muted">
                          {entry.rounds_count}
                        </td>
                        <td className="p-4 text-center text-foreground">
                          {entry.avg_score}
                        </td>
                        <td className="p-4 text-center text-accent-green font-medium">
                          {entry.best_score}
                        </td>
                        <td className="p-4 text-right">
                          <span className={cn(
                            "font-bold text-lg",
                            leaderboardType === "strokes_gained"
                              ? entry.avg_sg >= 0 ? "text-accent-green" : "text-accent-red"
                              : "text-foreground"
                          )}>
                            {getDisplayValue(entry)}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="py-12 text-center">
            <Trophy className="w-12 h-12 text-foreground-muted mx-auto mb-4" />
            <h3 className="text-lg font-medium text-foreground mb-2">No players yet</h3>
            <p className="text-foreground-muted mb-4">
              Be the first to make your profile public and appear on the leaderboard!
            </p>
            <p className="text-sm text-foreground-muted">
              Go to Profile → Edit Profile → Enable &quot;Make profile public&quot;
            </p>
          </CardContent>
        </Card>
      )}

      {/* Info Card */}
      <Card className="border-accent-blue/20">
        <CardContent className="py-4">
          <div className="flex items-start gap-4">
            <div className="w-10 h-10 rounded-lg bg-accent-blue/10 flex items-center justify-center flex-shrink-0">
              <User className="w-5 h-5 text-accent-blue" />
            </div>
            <div>
              <h3 className="font-medium text-foreground mb-1">Privacy Notice</h3>
              <p className="text-sm text-foreground-muted">
                Only players who have enabled &quot;Make profile public&quot; in their profile settings appear on this leaderboard.
                Your stats are private by default. Go to Profile to update your visibility settings.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

