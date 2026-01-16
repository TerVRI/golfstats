"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { Achievement, UserAchievement, AchievementTier, AchievementCategory } from "@/types/golf";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Trophy, Lock, Star, TrendingUp, Users, Target, Award } from "lucide-react";

const TIER_COLORS: Record<AchievementTier, string> = {
  bronze: "from-amber-700 to-amber-500",
  silver: "from-gray-400 to-gray-300",
  gold: "from-yellow-500 to-yellow-300",
  platinum: "from-cyan-400 to-purple-400",
};

const TIER_BG: Record<AchievementTier, string> = {
  bronze: "bg-amber-900/30 border-amber-700",
  silver: "bg-gray-700/30 border-gray-500",
  gold: "bg-yellow-900/30 border-yellow-600",
  platinum: "bg-gradient-to-br from-cyan-900/30 to-purple-900/30 border-purple-500",
};

const CATEGORY_ICONS: Record<AchievementCategory, React.ReactNode> = {
  scoring: <Target className="w-5 h-5" />,
  consistency: <Star className="w-5 h-5" />,
  improvement: <TrendingUp className="w-5 h-5" />,
  milestones: <Award className="w-5 h-5" />,
  social: <Users className="w-5 h-5" />,
};

const CATEGORY_LABELS: Record<AchievementCategory, string> = {
  scoring: "Scoring",
  consistency: "Consistency",
  improvement: "Improvement",
  milestones: "Milestones",
  social: "Social",
};

export default function AchievementsPage() {
  const { user } = useUser();
  const supabase = createClient();

  const [achievements, setAchievements] = useState<Achievement[]>([]);
  const [userAchievements, setUserAchievements] = useState<UserAchievement[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState<AchievementCategory | "all">("all");

  useEffect(() => {
    fetchAchievements();
  }, [user]);

  const fetchAchievements = async () => {
    // Fetch all achievement definitions
    const { data: allAchievements, error: achError } = await supabase
      .from("achievement_definitions")
      .select("*")
      .order("category")
      .order("tier");

    if (achError) {
      console.error("Error fetching achievements:", achError);
    } else {
      setAchievements(allAchievements || []);
    }

    // Fetch user's unlocked achievements
    if (user) {
      const { data: userAch, error: userError } = await supabase
        .from("user_achievements")
        .select("*")
        .eq("user_id", user.id);

      if (userError) {
        console.error("Error fetching user achievements:", userError);
      } else {
        setUserAchievements(userAch || []);
      }
    }

    setLoading(false);
  };

  const unlockedIds = new Set(userAchievements.map((ua) => ua.achievement_id));
  const totalPoints = userAchievements.reduce((sum, ua) => {
    const ach = achievements.find((a) => a.id === ua.achievement_id);
    return sum + (ach?.points || 0);
  }, 0);

  const filteredAchievements =
    selectedCategory === "all"
      ? achievements
      : achievements.filter((a) => a.category === selectedCategory);

  const categories: (AchievementCategory | "all")[] = [
    "all",
    "scoring",
    "consistency",
    "improvement",
    "milestones",
    "social",
  ];

  if (loading) {
    return (
      <div className="p-6 space-y-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-background-tertiary rounded w-48" />
          <div className="h-32 bg-background-tertiary rounded" />
          <div className="grid grid-cols-2 gap-4">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-24 bg-background-tertiary rounded" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Trophy className="w-7 h-7 text-accent-amber" />
            Achievements
          </h1>
          <p className="text-foreground-muted">
            {userAchievements.length} of {achievements.length} unlocked
          </p>
        </div>
        <div className="text-right">
          <div className="text-3xl font-bold gradient-text">{totalPoints}</div>
          <div className="text-sm text-foreground-muted">Total Points</div>
        </div>
      </div>

      {/* Progress Bar */}
      <Card>
        <CardContent className="py-4">
          <div className="flex items-center gap-4">
            <div className="flex-1">
              <div className="h-4 bg-background-tertiary rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-accent-green via-accent-blue to-purple-500 transition-all duration-500"
                  style={{
                    width: `${(userAchievements.length / achievements.length) * 100}%`,
                  }}
                />
              </div>
            </div>
            <div className="text-sm font-medium">
              {Math.round((userAchievements.length / achievements.length) * 100)}%
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Category Filter */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {categories.map((cat) => (
          <button
            key={cat}
            onClick={() => setSelectedCategory(cat)}
            className={`
              px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap
              transition-all flex items-center gap-2
              ${
                selectedCategory === cat
                  ? "bg-accent-green text-white"
                  : "bg-background-secondary hover:bg-background-tertiary"
              }
            `}
          >
            {cat !== "all" && CATEGORY_ICONS[cat]}
            {cat === "all" ? "All" : CATEGORY_LABELS[cat]}
          </button>
        ))}
      </div>

      {/* Achievements Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {filteredAchievements.map((achievement) => {
          const isUnlocked = unlockedIds.has(achievement.id);
          const userAch = userAchievements.find(
            (ua) => ua.achievement_id === achievement.id
          );

          return (
            <Card
              key={achievement.id}
              className={`
                relative overflow-hidden transition-all
                ${isUnlocked ? TIER_BG[achievement.tier] : "opacity-60"}
              `}
            >
              {/* Tier gradient overlay */}
              {isUnlocked && (
                <div
                  className={`
                    absolute top-0 right-0 w-32 h-32 
                    bg-gradient-to-bl ${TIER_COLORS[achievement.tier]} 
                    opacity-10 rounded-bl-full
                  `}
                />
              )}

              <CardContent className="p-4 flex items-start gap-4">
                {/* Icon */}
                <div
                  className={`
                    text-4xl w-16 h-16 flex items-center justify-center rounded-xl
                    ${
                      isUnlocked
                        ? `bg-gradient-to-br ${TIER_COLORS[achievement.tier]}`
                        : "bg-background-tertiary"
                    }
                  `}
                >
                  {isUnlocked ? (
                    achievement.icon
                  ) : (
                    <Lock className="w-6 h-6 text-foreground-muted" />
                  )}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-semibold truncate">{achievement.name}</h3>
                    <span
                      className={`
                        text-xs px-2 py-0.5 rounded-full capitalize
                        ${
                          isUnlocked
                            ? `bg-gradient-to-r ${TIER_COLORS[achievement.tier]} text-white`
                            : "bg-background-tertiary"
                        }
                      `}
                    >
                      {achievement.tier}
                    </span>
                  </div>
                  <p className="text-sm text-foreground-muted mb-2">
                    {achievement.description}
                  </p>
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-foreground-muted flex items-center gap-1">
                      {CATEGORY_ICONS[achievement.category]}
                      {CATEGORY_LABELS[achievement.category]}
                    </span>
                    <span className="text-sm font-medium text-accent-amber">
                      +{achievement.points} pts
                    </span>
                  </div>
                  {isUnlocked && userAch && (
                    <p className="text-xs text-accent-green mt-2">
                      Unlocked {new Date(userAch.unlocked_at).toLocaleDateString()}
                    </p>
                  )}
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* Recently Unlocked */}
      {userAchievements.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Recently Unlocked</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-4 overflow-x-auto pb-2">
              {userAchievements
                .sort(
                  (a, b) =>
                    new Date(b.unlocked_at).getTime() -
                    new Date(a.unlocked_at).getTime()
                )
                .slice(0, 5)
                .map((userAch) => {
                  const achievement = achievements.find(
                    (a) => a.id === userAch.achievement_id
                  );
                  if (!achievement) return null;

                  return (
                    <div
                      key={userAch.id}
                      className="flex-shrink-0 text-center w-20"
                    >
                      <div
                        className={`
                          text-3xl w-16 h-16 mx-auto mb-2 flex items-center justify-center rounded-xl
                          bg-gradient-to-br ${TIER_COLORS[achievement.tier]}
                        `}
                      >
                        {achievement.icon}
                      </div>
                      <p className="text-xs font-medium truncate">
                        {achievement.name}
                      </p>
                    </div>
                  );
                })}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Empty State */}
      {userAchievements.length === 0 && (
        <Card>
          <CardContent className="py-12 text-center">
            <Trophy className="w-16 h-16 mx-auto text-foreground-muted mb-4" />
            <h3 className="text-lg font-semibold mb-2">No achievements yet</h3>
            <p className="text-foreground-muted">
              Play rounds and improve your game to unlock achievements!
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
