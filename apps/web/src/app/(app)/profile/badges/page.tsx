"use client";

import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { fetchUserBadges, fetchBadgeDefinitions, calculateBadgeProgress, Badge, BadgeProgress } from "@/lib/badges";
import { Award, Trophy, Loader2, CheckCircle, Circle } from "lucide-react";

export default function BadgesPage() {
  const { user } = useUser();
  const [badges, setBadges] = useState<Badge[]>([]);
  const [badgeProgress, setBadgeProgress] = useState<BadgeProgress[]>([]);
  const [definitions, setDefinitions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<"earned" | "progress">("earned");

  useEffect(() => {
    async function loadBadges() {
      if (!user) return;

      try {
        const [userBadges, progress, defs] = await Promise.all([
          fetchUserBadges(user.id),
          calculateBadgeProgress(user.id),
          fetchBadgeDefinitions(),
        ]);

        setBadges(userBadges);
        setBadgeProgress(progress);
        setDefinitions(defs);
      } catch (err) {
        console.error("Error loading badges:", err);
      } finally {
        setLoading(false);
      }
    }

    loadBadges();
  }, [user]);

  const getCategoryColor = (category: string) => {
    switch (category) {
      case "completion":
        return "bg-green-500";
      case "quality":
        return "bg-blue-500";
      case "contribution":
        return "bg-purple-500";
      case "verification":
        return "bg-orange-500";
      default:
        return "bg-gray-500";
    }
  };

  const getEarnedBadges = () => {
    return badgeProgress.filter((b) => b.earned);
  };

  const getInProgressBadges = () => {
    return badgeProgress.filter((b) => !b.earned && b.progress > 0);
  };

  const getLockedBadges = () => {
    return badgeProgress.filter((b) => !b.earned && b.progress === 0);
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-foreground">My Badges</h1>
        <p className="text-foreground-muted">Track your achievements and progress</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="p-4">
          <div className="flex items-center gap-3">
            <Trophy className="w-8 h-8 text-yellow-500" />
            <div>
              <p className="text-2xl font-bold text-foreground">{badges.length}</p>
              <p className="text-sm text-foreground-muted">Badges Earned</p>
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-center gap-3">
            <Award className="w-8 h-8 text-blue-500" />
            <div>
              <p className="text-2xl font-bold text-foreground">{getInProgressBadges().length}</p>
              <p className="text-sm text-foreground-muted">In Progress</p>
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-center gap-3">
            <Circle className="w-8 h-8 text-gray-500" />
            <div>
              <p className="text-2xl font-bold text-foreground">{getLockedBadges().length}</p>
              <p className="text-sm text-foreground-muted">Locked</p>
            </div>
          </div>
        </Card>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-border">
        <button
          onClick={() => setActiveTab("earned")}
          className={`px-4 py-2 font-medium ${
            activeTab === "earned"
              ? "text-foreground border-b-2 border-accent-green"
              : "text-foreground-muted"
          }`}
        >
          Earned ({badges.length})
        </button>
        <button
          onClick={() => setActiveTab("progress")}
          className={`px-4 py-2 font-medium ${
            activeTab === "progress"
              ? "text-foreground border-b-2 border-accent-green"
              : "text-foreground-muted"
          }`}
        >
          All Badges ({badgeProgress.length})
        </button>
      </div>

      {/* Earned Badges */}
      {activeTab === "earned" && (
        <div>
          {badges.length === 0 ? (
            <Card className="p-12 text-center">
              <Award className="w-12 h-12 mx-auto mb-4 text-foreground-muted opacity-50" />
              <p className="text-foreground-muted">No badges earned yet</p>
              <p className="text-sm text-foreground-muted mt-2">
                Complete courses to start earning badges!
              </p>
            </Card>
          ) : (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {badges.map((badge) => {
                const def = definitions.find((d) => d.badge_type === badge.badge_type);
                return (
                  <Card key={badge.id} className="p-4">
                    <div className="flex items-start gap-3">
                      <div className="text-4xl">{badge.badge_icon || "🏆"}</div>
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <h3 className="font-semibold text-foreground">{badge.badge_name}</h3>
                          <CheckCircle className="w-4 h-4 text-green-500" />
                        </div>
                        <p className="text-sm text-foreground-muted mb-2">
                          {badge.badge_description || def?.badge_description}
                        </p>
                        {def && (
                          <Badge
                            variant="outline"
                            className={`text-xs ${getCategoryColor(def.category)} text-white`}
                          >
                            {def.category}
                          </Badge>
                        )}
                        <p className="text-xs text-foreground-muted mt-2">
                          Earned {new Date(badge.earned_at).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  </Card>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* All Badges with Progress */}
      {activeTab === "progress" && (
        <div className="space-y-6">
          {/* Earned Section */}
          {getEarnedBadges().length > 0 && (
            <div>
              <h2 className="text-lg font-semibold text-foreground mb-4">Earned</h2>
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {getEarnedBadges().map((badge) => {
                  const def = definitions.find((d) => d.badge_type === badge.badge_type);
                  return (
                    <Card key={badge.badge_type} className="p-4">
                      <div className="flex items-start gap-3">
                        <div className="text-4xl">{def?.badge_icon || "🏆"}</div>
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-1">
                            <h3 className="font-semibold text-foreground">{badge.badge_name}</h3>
                            <CheckCircle className="w-4 h-4 text-green-500" />
                          </div>
                          <p className="text-sm text-foreground-muted">{def?.badge_description}</p>
                          <div className="mt-2">
                            <div className="w-full bg-background-secondary rounded-full h-2">
                              <div
                                className="bg-green-500 h-2 rounded-full"
                                style={{ width: "100%" }}
                              />
                            </div>
                          </div>
                        </div>
                      </div>
                    </Card>
                  );
                })}
              </div>
            </div>
          )}

          {/* In Progress Section */}
          {getInProgressBadges().length > 0 && (
            <div>
              <h2 className="text-lg font-semibold text-foreground mb-4">In Progress</h2>
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {getInProgressBadges().map((badge) => {
                  const def = definitions.find((d) => d.badge_type === badge.badge_type);
                  return (
                    <Card key={badge.badge_type} className="p-4">
                      <div className="flex items-start gap-3">
                        <div className="text-4xl opacity-50">{def?.badge_icon || "🏆"}</div>
                        <div className="flex-1">
                          <h3 className="font-semibold text-foreground mb-1">{badge.badge_name}</h3>
                          <p className="text-sm text-foreground-muted mb-2">{def?.badge_description}</p>
                          <div className="mt-2">
                            <div className="flex justify-between text-xs text-foreground-muted mb-1">
                              <span>Progress</span>
                              <span>{badge.progress}%</span>
                            </div>
                            <div className="w-full bg-background-secondary rounded-full h-2">
                              <div
                                className="bg-blue-500 h-2 rounded-full transition-all"
                                style={{ width: `${badge.progress}%` }}
                              />
                            </div>
                          </div>
                        </div>
                      </div>
                    </Card>
                  );
                })}
              </div>
            </div>
          )}

          {/* Locked Section */}
          {getLockedBadges().length > 0 && (
            <div>
              <h2 className="text-lg font-semibold text-foreground mb-4">Locked</h2>
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {getLockedBadges().map((badge) => {
                  const def = definitions.find((d) => d.badge_type === badge.badge_type);
                  return (
                    <Card key={badge.badge_type} className="p-4 opacity-60">
                      <div className="flex items-start gap-3">
                        <div className="text-4xl grayscale">{def?.badge_icon || "🏆"}</div>
                        <div className="flex-1">
                          <h3 className="font-semibold text-foreground mb-1">{badge.badge_name}</h3>
                          <p className="text-sm text-foreground-muted">{def?.badge_description}</p>
                          {def?.requirement_description && (
                            <p className="text-xs text-foreground-muted mt-2">
                              {def.requirement_description}
                            </p>
                          )}
                        </div>
                      </div>
                    </Card>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
