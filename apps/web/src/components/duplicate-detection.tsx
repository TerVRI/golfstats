"use client";

import { useState, useEffect } from "react";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { detectDuplicates } from "@/lib/course-validation";
import { AlertTriangle, CheckCircle2, XCircle, Loader2 } from "lucide-react";
import Link from "next/link";

interface DuplicateSuggestion {
  id: string;
  course1_id: string;
  course2_id: string;
  course1_name: string;
  course2_name: string;
  similarity_score: number;
  status: string;
  reasons: string[];
}

export function DuplicateDetection() {
  const { user } = useUser();
  const supabase = createClient();
  const [duplicates, setDuplicates] = useState<DuplicateSuggestion[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDuplicates();
  }, []);

  const fetchDuplicates = async () => {
    try {
      const { data, error } = await supabase
        .from("course_duplicates")
        .select(
          `
          *,
          course1:courses!course_duplicates_course1_id_fkey(name),
          course2:courses!course_duplicates_course2_id_fkey(name)
        `
        )
        .eq("status", "pending")
        .order("similarity_score", { ascending: false })
        .limit(20);

      if (error) throw error;

      setDuplicates(
        (data || []).map((d: any) => ({
          id: d.id,
          course1_id: d.course1_id,
          course2_id: d.course2_id,
          course1_name: d.course1?.name || "Unknown",
          course2_name: d.course2?.name || "Unknown",
          similarity_score: d.similarity_score,
          status: d.status,
          reasons: [], // Would come from detection logic
        }))
      );
    } catch (err) {
      console.error("Error fetching duplicates:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleVote = async (duplicateId: string, vote: "merge" | "keep_separate") => {
    if (!user) return;

    try {
      const { error } = await supabase.from("duplicate_votes").upsert({
        duplicate_id: duplicateId,
        user_id: user.id,
        vote,
      });

      if (error) throw error;

      // Update vote counts
      const { data: votes } = await supabase
        .from("duplicate_votes")
        .select("vote")
        .eq("duplicate_id", duplicateId);

      const mergeVotes = votes?.filter((v) => v.vote === "merge").length || 0;
      const keepVotes = votes?.filter((v) => v.vote === "keep_separate").length || 0;

      await supabase
        .from("course_duplicates")
        .update({
          merge_votes: mergeVotes,
          keep_separate_votes: keepVotes,
        })
        .eq("id", duplicateId);

      fetchDuplicates();
    } catch (err) {
      console.error("Error voting:", err);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="w-6 h-6 animate-spin text-accent-green" />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-semibold text-foreground mb-2">
          Potential Duplicate Courses
        </h2>
        <p className="text-sm text-foreground-muted">
          Help us identify and merge duplicate course entries
        </p>
      </div>

      {duplicates.length === 0 ? (
        <Card className="p-8 text-center">
          <CheckCircle2 className="w-12 h-12 text-accent-green mx-auto mb-2 opacity-50" />
          <p className="text-foreground-muted">No duplicate suggestions</p>
        </Card>
      ) : (
        <div className="space-y-4">
          {duplicates.map((duplicate) => (
            <Card key={duplicate.id} className="p-4">
              <div className="flex items-start justify-between mb-4">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <AlertTriangle className="w-5 h-5 text-accent-amber" />
                    <span className="font-semibold text-foreground">
                      {Math.round(duplicate.similarity_score)}% Similar
                    </span>
                  </div>
                  <div className="space-y-2">
                    <div>
                      <Link
                        href={`/courses/${duplicate.course1_id}`}
                        className="text-accent-blue hover:underline"
                      >
                        {duplicate.course1_name}
                      </Link>
                    </div>
                    <div className="text-foreground-muted">vs</div>
                    <div>
                      <Link
                        href={`/courses/${duplicate.course2_id}`}
                        className="text-accent-blue hover:underline"
                      >
                        {duplicate.course2_name}
                      </Link>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex gap-2 mt-4">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => handleVote(duplicate.id, "merge")}
                  className="flex-1"
                >
                  <CheckCircle2 className="w-4 h-4 mr-1" />
                  Merge
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => handleVote(duplicate.id, "keep_separate")}
                  className="flex-1"
                >
                  <XCircle className="w-4 h-4 mr-1" />
                  Keep Separate
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
