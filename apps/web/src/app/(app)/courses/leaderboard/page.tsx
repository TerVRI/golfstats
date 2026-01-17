"use client";

import { useState, useEffect, useCallback } from "react";
import { Card } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/client";
import {
  Trophy,
  Medal,
  Award,
  MapPin,
  CheckCircle2,
  Loader2,
} from "lucide-react";
import Link from "next/link";

interface Contributor {
  id: string;
  full_name: string | null;
  avatar_url: string | null;
  total_contributions: number;
  approved_contributions: number;
  verified_courses: number;
  pending_contributions: number;
}

export default function CourseLeaderboardPage() {
  const supabase = createClient();
  const [contributors, setContributors] = useState<Contributor[]>([]);
  const [loading, setLoading] = useState(true);
  const [sortBy, setSortBy] = useState<"total" | "verified">("total");

  const fetchLeaderboard = useCallback(async () => {
    try {
      // Get all course contributions grouped by contributor
      const { data: contributions, error: contribError } = await supabase
        .from("course_contributions")
        .select("contributor_id, status, profiles(full_name, avatar_url)")
        .in("status", ["approved", "merged", "pending"]);

      if (contribError) throw contribError;

      // Get all courses with contributors
      const { data: courses, error: coursesError } = await supabase
        .from("courses")
        .select("id, contributed_by, is_verified, profiles(full_name, avatar_url)");

      if (coursesError) throw coursesError;

      // Aggregate data by contributor
      const contributorMap = new Map<string, Contributor>();

      // Process contributions
      contributions?.forEach((contrib: any) => {
        const userId = contrib.contributor_id;
        if (!contributorMap.has(userId)) {
          contributorMap.set(userId, {
            id: userId,
            full_name: contrib.profiles?.full_name || null,
            avatar_url: contrib.profiles?.avatar_url || null,
            total_contributions: 0,
            approved_contributions: 0,
            verified_courses: 0,
            pending_contributions: 0,
          });
        }

        const contributor = contributorMap.get(userId)!;
        contributor.total_contributions++;
        if (contrib.status === "approved" || contrib.status === "merged") {
          contributor.approved_contributions++;
        } else if (contrib.status === "pending") {
          contributor.pending_contributions++;
        }
      });

      // Process verified courses
      courses?.forEach((course: any) => {
        if (course.contributed_by && course.is_verified) {
          const userId = course.contributed_by;
          if (!contributorMap.has(userId)) {
            contributorMap.set(userId, {
              id: userId,
              full_name: course.profiles?.full_name || null,
              avatar_url: course.profiles?.avatar_url || null,
              total_contributions: 0,
              approved_contributions: 0,
              verified_courses: 0,
              pending_contributions: 0,
            });
          }
          contributorMap.get(userId)!.verified_courses++;
        }
      });

      // Convert to array and sort
      const sorted = Array.from(contributorMap.values()).sort((a, b) => {
        if (sortBy === "verified") {
          return b.verified_courses - a.verified_courses;
        }
        return b.total_contributions - a.total_contributions;
      });

      setContributors(sorted);
    } catch (err) {
      console.error("Error fetching leaderboard:", err);
    } finally {
      setLoading(false);
    }
  }, [supabase, sortBy]);

  useEffect(() => {
    fetchLeaderboard();
  }, [fetchLeaderboard]);

  const getRankIcon = (index: number) => {
    if (index === 0) return <Trophy className="w-6 h-6 text-accent-amber" />;
    if (index === 1) return <Medal className="w-6 h-6 text-gray-400" />;
    if (index === 2) return <Award className="w-6 h-6 text-amber-600" />;
    return <span className="text-foreground-muted font-bold">{index + 1}</span>;
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto py-8">
      <div className="mb-6">
        <Link
          href="/courses"
          className="text-foreground-muted hover:text-foreground inline-flex items-center gap-1 mb-4"
        >
          ← Back to Courses
        </Link>
        <h1 className="text-3xl font-bold text-foreground mb-2">
          Course Contributors Leaderboard
        </h1>
        <p className="text-foreground-muted">
          Top contributors helping build our course database
        </p>
      </div>

      {/* Sort Options */}
      <Card className="p-4 mb-6">
        <div className="flex items-center gap-4">
          <span className="text-foreground-muted">Sort by:</span>
          <button
            onClick={() => setSortBy("total")}
            className={`px-4 py-2 rounded-lg transition-colors ${
              sortBy === "total"
                ? "bg-accent-green text-white"
                : "bg-background-secondary text-foreground hover:bg-background-tertiary"
            }`}
          >
            Total Contributions
          </button>
          <button
            onClick={() => setSortBy("verified")}
            className={`px-4 py-2 rounded-lg transition-colors ${
              sortBy === "verified"
                ? "bg-accent-green text-white"
                : "bg-background-secondary text-foreground hover:bg-background-tertiary"
            }`}
          >
            Verified Courses
          </button>
        </div>
      </Card>

      {/* Leaderboard */}
      {contributors.length === 0 ? (
        <Card className="p-8 text-center">
          <p className="text-foreground-muted">
            No contributors yet. Be the first to contribute a course!
          </p>
          <Link href="/courses/contribute">
            <button className="mt-4 px-6 py-2 bg-accent-green text-white rounded-lg hover:bg-accent-green/90">
              Contribute a Course
            </button>
          </Link>
        </Card>
      ) : (
        <div className="space-y-4">
          {contributors.map((contributor, index) => (
            <Card key={contributor.id} className="p-6">
              <div className="flex items-center gap-4">
                {/* Rank */}
                <div className="flex items-center justify-center w-12 h-12">
                  {getRankIcon(index)}
                </div>

                {/* Avatar */}
                <div className="w-12 h-12 rounded-full bg-background-secondary flex items-center justify-center overflow-hidden">
                  {contributor.avatar_url ? (
                    <img
                      src={contributor.avatar_url}
                      alt={contributor.full_name || "Contributor"}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <MapPin className="w-6 h-6 text-foreground-muted" />
                  )}
                </div>

                {/* Name and Stats */}
                <div className="flex-1">
                  <h3 className="font-semibold text-foreground">
                    {contributor.full_name || "Anonymous Contributor"}
                  </h3>
                  <div className="flex gap-6 mt-2 text-sm">
                    <div className="flex items-center gap-1">
                      <MapPin className="w-4 h-4 text-foreground-muted" />
                      <span className="text-foreground-muted">
                        {contributor.total_contributions} total
                      </span>
                    </div>
                    <div className="flex items-center gap-1">
                      <CheckCircle2 className="w-4 h-4 text-accent-green" />
                      <span className="text-foreground-muted">
                        {contributor.verified_courses} verified
                      </span>
                    </div>
                    <div className="text-foreground-muted">
                      {contributor.approved_contributions} approved
                    </div>
                    {contributor.pending_contributions > 0 && (
                      <div className="text-accent-amber">
                        {contributor.pending_contributions} pending
                      </div>
                    )}
                  </div>
                </div>

                {/* Score */}
                <div className="text-right">
                  <div className="text-2xl font-bold text-foreground">
                    {sortBy === "verified"
                      ? contributor.verified_courses
                      : contributor.total_contributions}
                  </div>
                  <div className="text-sm text-foreground-muted">
                    {sortBy === "verified" ? "verified" : "contributions"}
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* Call to Action */}
      <Card className="p-6 mt-6 bg-accent-green/10 border-accent-green/20">
        <div className="text-center">
          <h3 className="text-lg font-semibold text-foreground mb-2">
            Want to be on the leaderboard?
          </h3>
          <p className="text-foreground-muted mb-4">
            Contribute course data and help build our database. Earn badges and
            recognition for your contributions!
          </p>
          <Link href="/courses/contribute">
            <button className="px-6 py-2 bg-accent-green text-white rounded-lg hover:bg-accent-green/90">
              Contribute a Course
            </button>
          </Link>
        </div>
      </Card>
    </div>
  );
}
