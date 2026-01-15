"use client";

import { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent, Button, Input } from "@/components/ui";
import { createClient } from "@/lib/supabase/client";
import { cn, formatDate } from "@/lib/utils";
import {
  User,
  Trophy,
  Target,
  TrendingUp,
  TrendingDown,
  Calendar,
  MapPin,
  Save,
  Loader2,
  Award,
  Flag,
} from "lucide-react";

interface Profile {
  id: string;
  email: string;
  name: string | null;
  handicap: number | null;
  avatar_url: string | null;
  bio: string | null;
  is_public: boolean;
  home_course: string | null;
  low_handicap: number | null;
  rounds_played: number;
}

interface RoundStats {
  total_rounds: number;
  avg_score: number;
  best_score: number;
  worst_score: number;
  avg_putts: number;
  avg_gir: number;
  avg_fairways: number;
  calculated_handicap: number | null;
}

export default function ProfilePage() {
  const supabase = createClient();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [stats, setStats] = useState<RoundStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [editMode, setEditMode] = useState(false);
  
  // Editable fields
  const [name, setName] = useState("");
  const [bio, setBio] = useState("");
  const [homeCourse, setHomeCourse] = useState("");
  const [isPublic, setIsPublic] = useState(false);

  useEffect(() => {
    async function loadProfile() {
      setIsLoading(true);
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        // Get profile
        const { data: profileData } = await supabase
          .from("profiles")
          .select("*")
          .eq("id", user.id)
          .single();

        if (profileData) {
          setProfile(profileData);
          setName(profileData.name || "");
          setBio(profileData.bio || "");
          setHomeCourse(profileData.home_course || "");
          setIsPublic(profileData.is_public || false);
        }

        // Get round statistics
        const { data: rounds } = await supabase
          .from("rounds")
          .select("total_score, total_putts, gir, fairways_hit, fairways_total, course_rating, slope_rating")
          .eq("user_id", user.id);

        if (rounds && rounds.length > 0) {
          const totalRounds = rounds.length;
          const avgScore = rounds.reduce((sum, r) => sum + r.total_score, 0) / totalRounds;
          const bestScore = Math.min(...rounds.map(r => r.total_score));
          const worstScore = Math.max(...rounds.map(r => r.total_score));
          const avgPutts = rounds.reduce((sum, r) => sum + (r.total_putts || 0), 0) / totalRounds;
          const avgGir = rounds.reduce((sum, r) => sum + (r.gir || 0), 0) / totalRounds;
          const avgFairways = rounds.reduce((sum, r) => sum + ((r.fairways_hit || 0) / (r.fairways_total || 14)), 0) / totalRounds * 100;

          // Calculate handicap index
          const roundsWithRating = rounds.filter(r => r.course_rating && r.slope_rating);
          let calculatedHandicap: number | null = null;
          
          if (roundsWithRating.length >= 3) {
            const differentials = roundsWithRating
              .map(r => ((r.total_score - r.course_rating!) * 113) / r.slope_rating!)
              .sort((a, b) => a - b);
            
            // Use best 40% of rounds (minimum 1)
            const numToUse = Math.max(1, Math.floor(differentials.length * 0.4));
            const bestDiffs = differentials.slice(0, numToUse);
            calculatedHandicap = Math.round((bestDiffs.reduce((a, b) => a + b, 0) / bestDiffs.length) * 0.96 * 10) / 10;
          }

          setStats({
            total_rounds: totalRounds,
            avg_score: Math.round(avgScore * 10) / 10,
            best_score: bestScore,
            worst_score: worstScore,
            avg_putts: Math.round(avgPutts * 10) / 10,
            avg_gir: Math.round(avgGir * 10) / 10,
            avg_fairways: Math.round(avgFairways),
            calculated_handicap: calculatedHandicap,
          });
        }
      } catch (err) {
        console.error("Error loading profile:", err);
      } finally {
        setIsLoading(false);
      }
    }

    loadProfile();
  }, [supabase]);

  const handleSave = async () => {
    if (!profile) return;
    setIsSaving(true);
    
    try {
      const { error } = await supabase
        .from("profiles")
        .update({
          name,
          bio,
          home_course: homeCourse,
          is_public: isPublic,
          handicap: stats?.calculated_handicap,
        })
        .eq("id", profile.id);

      if (error) throw error;
      
      setProfile({ ...profile, name, bio, home_course: homeCourse, is_public: isPublic, handicap: stats?.calculated_handicap || null });
      setEditMode(false);
    } catch (err) {
      console.error("Error saving profile:", err);
    } finally {
      setIsSaving(false);
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
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Profile</h1>
          <p className="text-foreground-muted mt-1">
            Your golf profile and statistics
          </p>
        </div>
        {!editMode ? (
          <Button onClick={() => setEditMode(true)}>
            Edit Profile
          </Button>
        ) : (
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => setEditMode(false)}>
              Cancel
            </Button>
            <Button onClick={handleSave} disabled={isSaving}>
              {isSaving ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Save className="w-4 h-4 mr-2" />}
              Save
            </Button>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Profile Card */}
        <Card className="lg:col-span-1">
          <CardContent className="pt-6">
            <div className="text-center">
              <div className="w-24 h-24 rounded-full bg-accent-green/10 flex items-center justify-center mx-auto mb-4">
                <User className="w-12 h-12 text-accent-green" />
              </div>
              
              {editMode ? (
                <div className="space-y-4 text-left">
                  <Input
                    label="Name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Your name"
                  />
                  <Input
                    label="Home Course"
                    value={homeCourse}
                    onChange={(e) => setHomeCourse(e.target.value)}
                    placeholder="Your home course"
                  />
                  <div>
                    <label className="block text-sm font-medium text-foreground-muted mb-2">Bio</label>
                    <textarea
                      value={bio}
                      onChange={(e) => setBio(e.target.value)}
                      placeholder="Tell us about your golf game..."
                      className="w-full px-4 py-2 rounded-lg bg-background-secondary border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green resize-none"
                      rows={3}
                    />
                  </div>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={isPublic}
                      onChange={(e) => setIsPublic(e.target.checked)}
                      className="w-4 h-4 rounded border-card-border text-accent-green focus:ring-accent-green"
                    />
                    <span className="text-sm text-foreground-muted">Make profile public</span>
                  </label>
                </div>
              ) : (
                <>
                  <h2 className="text-xl font-bold text-foreground">{profile?.name || "Golfer"}</h2>
                  <p className="text-foreground-muted text-sm">{profile?.email}</p>
                  
                  {profile?.home_course && (
                    <div className="flex items-center justify-center gap-1 mt-2 text-foreground-muted">
                      <MapPin className="w-4 h-4" />
                      <span className="text-sm">{profile.home_course}</span>
                    </div>
                  )}
                  
                  {profile?.bio && (
                    <p className="mt-4 text-foreground-muted text-sm">{profile.bio}</p>
                  )}
                </>
              )}
            </div>

            {/* Handicap Display */}
            <div className="mt-6 p-4 rounded-lg bg-gradient-to-br from-accent-green/10 to-accent-blue/10 text-center">
              <p className="text-sm text-foreground-muted mb-1">Handicap Index</p>
              <p className="text-4xl font-bold text-accent-green">
                {stats?.calculated_handicap?.toFixed(1) ?? "N/A"}
              </p>
              {stats && stats.total_rounds < 3 && (
                <p className="text-xs text-foreground-muted mt-2">
                  Need {3 - stats.total_rounds} more rounds with ratings
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Statistics */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Trophy className="w-5 h-5 text-accent-amber" />
              Career Statistics
            </CardTitle>
          </CardHeader>
          <CardContent>
            {stats ? (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <Calendar className="w-5 h-5 text-accent-blue mx-auto mb-2" />
                  <p className="text-2xl font-bold text-foreground">{stats.total_rounds}</p>
                  <p className="text-xs text-foreground-muted">Rounds Played</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <Target className="w-5 h-5 text-accent-purple mx-auto mb-2" />
                  <p className="text-2xl font-bold text-foreground">{stats.avg_score}</p>
                  <p className="text-xs text-foreground-muted">Average Score</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <TrendingDown className="w-5 h-5 text-accent-green mx-auto mb-2" />
                  <p className="text-2xl font-bold text-accent-green">{stats.best_score}</p>
                  <p className="text-xs text-foreground-muted">Best Score</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <TrendingUp className="w-5 h-5 text-accent-red mx-auto mb-2" />
                  <p className="text-2xl font-bold text-accent-red">{stats.worst_score}</p>
                  <p className="text-xs text-foreground-muted">Worst Score</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <Flag className="w-5 h-5 text-accent-amber mx-auto mb-2" />
                  <p className="text-2xl font-bold text-foreground">{stats.avg_putts}</p>
                  <p className="text-xs text-foreground-muted">Avg Putts/Round</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <Target className="w-5 h-5 text-accent-green mx-auto mb-2" />
                  <p className="text-2xl font-bold text-foreground">{stats.avg_gir}</p>
                  <p className="text-xs text-foreground-muted">Avg GIR/Round</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <Award className="w-5 h-5 text-accent-blue mx-auto mb-2" />
                  <p className="text-2xl font-bold text-foreground">{stats.avg_fairways}%</p>
                  <p className="text-xs text-foreground-muted">Fairways Hit</p>
                </div>
                
                <div className="p-4 rounded-lg bg-background-secondary text-center">
                  <Trophy className="w-5 h-5 text-accent-amber mx-auto mb-2" />
                  <p className="text-2xl font-bold text-foreground">
                    {stats.calculated_handicap?.toFixed(1) ?? "—"}
                  </p>
                  <p className="text-xs text-foreground-muted">Handicap Index</p>
                </div>
              </div>
            ) : (
              <div className="text-center py-8">
                <Target className="w-12 h-12 text-foreground-muted mx-auto mb-4" />
                <p className="text-foreground-muted">No rounds logged yet</p>
                <p className="text-sm text-foreground-muted">Start logging rounds to see your statistics</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Handicap Explanation */}
      <Card>
        <CardHeader>
          <CardTitle>How Handicap Index is Calculated</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="prose prose-invert max-w-none">
            <p className="text-foreground-muted">
              Your Handicap Index is calculated using the World Handicap System (WHS) formula:
            </p>
            <ol className="list-decimal list-inside space-y-2 text-foreground-muted mt-4">
              <li>
                <strong className="text-foreground">Score Differential</strong> = (Score - Course Rating) × 113 ÷ Slope Rating
              </li>
              <li>
                <strong className="text-foreground">Best Differentials</strong> = Average of best 40% of your last 20 rounds
              </li>
              <li>
                <strong className="text-foreground">Handicap Index</strong> = Best Differentials × 0.96
              </li>
            </ol>
            <p className="text-foreground-muted mt-4">
              You need at least <strong className="text-foreground">3 rounds</strong> with course and slope ratings to calculate your handicap.
              For best accuracy, enter the course rating and slope for each round you log.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

