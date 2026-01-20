"use client";

import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { createClient } from "@/lib/supabase/client";
import { Trophy, Award, MapPin, Loader2, Calendar, Globe, CheckCircle } from "lucide-react";

interface LeaderboardEntry {
  user_id: string;
  user_name: string | null;
  completions_count: number;
  verified_count: number;
  geocoded_count: number;
  countries_count: number;
  rank: number;
}

export default function CompletionLeaderboardPage() {
  const supabase = createClient();
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<"month" | "all">("all");

  useEffect(() => {
    async function loadLeaderboard() {
      setLoading(true);
      try {
        // Query for top completers
        const { data, error } = await supabase
          .from("course_contributions")
          .select(`
            completed_by,
            profiles!course_contributions_completed_by_fkey(name),
            status,
            geocoded,
            country
          `)
          .not("completed_by", "is", null);

        if (error) throw error;

        // Process data to get statistics per user
        const userStats: Record<string, LeaderboardEntry> = {};

        data?.forEach((entry: any) => {
          const userId = entry.completed_by;
          if (!userId) return;

          if (!userStats[userId]) {
            userStats[userId] = {
              user_id: userId,
              user_name: entry.profiles?.name || "Anonymous",
              completions_count: 0,
              verified_count: 0,
              geocoded_count: 0,
              countries_count: 0,
              rank: 0,
            };
          }

          userStats[userId].completions_count++;
          if (entry.status === "approved") {
            userStats[userId].verified_count++;
          }
          if (entry.geocoded) {
            userStats[userId].geocoded_count++;
          }
        });

        // Get unique countries per user
        const countriesByUser: Record<string, Set<string>> = {};
        data?.forEach((entry: any) => {
          if (entry.completed_by && entry.country) {
            if (!countriesByUser[entry.completed_by]) {
              countriesByUser[entry.completed_by] = new Set();
            }
            countriesByUser[entry.completed_by].add(entry.country);
          }
        });

        Object.keys(countriesByUser).forEach((userId) => {
          if (userStats[userId]) {
            userStats[userId].countries_count = countriesByUser[userId].size;
          }
        });

        // Convert to array and sort
        let entries = Object.values(userStats);
        
        // Filter by time range if needed
        if (timeRange === "month") {
          // This would require a date filter - for now, show all
          // In production, you'd filter by completed_at >= NOW() - INTERVAL '1 month'
        }

        // Sort by verified count first, then total completions
        entries.sort((a, b) => {
          if (b.verified_count !== a.verified_count) {
            return b.verified_count - a.verified_count;
          }
          return b.completions_count - a.completions_count;
        });

        // Add ranks
        entries = entries.map((entry, index) => ({
          ...entry,
          rank: index + 1,
        }));

        setLeaderboard(entries.slice(0, 100)); // Top 100
      } catch (err) {
        console.error("Error loading leaderboard:", err);
      } finally {
        setLoading(false);
      }
    }

    loadLeaderboard();
  }, [supabase, timeRange]);

  const getRankIcon = (rank: number) => {
    if (rank === 1) return "🥇";
    if (rank === 2) return "🥈";
    if (rank === 3) return "🥉";
    return `#${rank}`;
  };

  const getRankColor = (rank: number) => {
    if (rank === 1) return "text-yellow-500";
    if (rank === 2) return "text-gray-400";
    if (rank === 3) return "text-orange-600";
    return "text-foreground-muted";
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Completion Leaderboard</h1>
          <p className="text-foreground-muted">Top course completers</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setTimeRange("all")}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              timeRange === "all"
                ? "bg-accent-green text-white"
                : "bg-background-secondary text-foreground"
            }`}
          >
            All Time
          </button>
          <button
            onClick={() => setTimeRange("month")}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              timeRange === "month"
                ? "bg-accent-green text-white"
                : "bg-background-secondary text-foreground"
            }`}
          >
            This Month
          </button>
        </div>
      </div>

      {/* Leaderboard */}
      {loading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
        </div>
      ) : leaderboard.length === 0 ? (
        <Card className="p-12 text-center">
          <Trophy className="w-12 h-12 mx-auto mb-4 text-foreground-muted opacity-50" />
          <p className="text-foreground-muted">No completions yet</p>
          <p className="text-sm text-foreground-muted mt-2">
            Be the first to complete a course!
          </p>
        </Card>
      ) : (
        <div className="space-y-4">
          {/* Top 3 Podium */}
          {leaderboard.length >= 3 && (
            <div className="grid grid-cols-3 gap-4 mb-8">
              {/* 2nd Place */}
              <Card className="p-6 text-center">
                <div className="text-4xl mb-2">🥈</div>
                <div className={`text-2xl font-bold mb-1 ${getRankColor(2)}`}>2</div>
                <h3 className="font-semibold text-foreground">{leaderboard[1]?.user_name || "Anonymous"}</h3>
                <div className="mt-3 space-y-1 text-sm">
                  <div className="flex items-center justify-center gap-1 text-foreground-muted">
                    <CheckCircle className="w-4 h-4" />
                    <span>{leaderboard[1]?.verified_count || 0} verified</span>
                  </div>
                  <div className="flex items-center justify-center gap-1 text-foreground-muted">
                    <MapPin className="w-4 h-4" />
                    <span>{leaderboard[1]?.completions_count || 0} total</span>
                  </div>
                </div>
              </Card>

              {/* 1st Place */}
              <Card className="p-6 text-center border-2 border-yellow-500">
                <div className="text-4xl mb-2">🥇</div>
                <div className={`text-2xl font-bold mb-1 ${getRankColor(1)}`}>1</div>
                <h3 className="font-semibold text-foreground text-lg">{leaderboard[0]?.user_name || "Anonymous"}</h3>
                <div className="mt-3 space-y-1 text-sm">
                  <div className="flex items-center justify-center gap-1 text-foreground-muted">
                    <CheckCircle className="w-4 h-4" />
                    <span>{leaderboard[0]?.verified_count || 0} verified</span>
                  </div>
                  <div className="flex items-center justify-center gap-1 text-foreground-muted">
                    <MapPin className="w-4 h-4" />
                    <span>{leaderboard[0]?.completions_count || 0} total</span>
                  </div>
                </div>
              </Card>

              {/* 3rd Place */}
              <Card className="p-6 text-center">
                <div className="text-4xl mb-2">🥉</div>
                <div className={`text-2xl font-bold mb-1 ${getRankColor(3)}`}>3</div>
                <h3 className="font-semibold text-foreground">{leaderboard[2]?.user_name || "Anonymous"}</h3>
                <div className="mt-3 space-y-1 text-sm">
                  <div className="flex items-center justify-center gap-1 text-foreground-muted">
                    <CheckCircle className="w-4 h-4" />
                    <span>{leaderboard[2]?.verified_count || 0} verified</span>
                  </div>
                  <div className="flex items-center justify-center gap-1 text-foreground-muted">
                    <MapPin className="w-4 h-4" />
                    <span>{leaderboard[2]?.completions_count || 0} total</span>
                  </div>
                </div>
              </Card>
            </div>
          )}

          {/* Rest of Leaderboard */}
          <div className="space-y-2">
            {leaderboard.slice(3).map((entry) => (
              <Card key={entry.user_id} className="p-4">
                <div className="flex items-center gap-4">
                  <div className={`text-xl font-bold w-12 text-center ${getRankColor(entry.rank)}`}>
                    {entry.rank}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold text-foreground">{entry.user_name || "Anonymous"}</h3>
                    <div className="flex gap-4 mt-1 text-sm text-foreground-muted">
                      <div className="flex items-center gap-1">
                        <CheckCircle className="w-3 h-3" />
                        <span>{entry.verified_count} verified</span>
                      </div>
                      <div className="flex items-center gap-1">
                        <MapPin className="w-3 h-3" />
                        <span>{entry.completions_count} total</span>
                      </div>
                      {entry.geocoded_count > 0 && (
                        <div className="flex items-center gap-1">
                          <Globe className="w-3 h-3" />
                          <span>{entry.geocoded_count} geocoded</span>
                        </div>
                      )}
                      {entry.countries_count > 0 && (
                        <div className="flex items-center gap-1">
                          <Globe className="w-3 h-3" />
                          <span>{entry.countries_count} countries</span>
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-lg font-bold text-foreground">{entry.verified_count}</div>
                    <div className="text-xs text-foreground-muted">points</div>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
