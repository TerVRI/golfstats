"use client";

import { useState, useEffect, useCallback, use } from "react";
import { useRouter } from "next/navigation";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import {
  CheckCircle2,
  XCircle,
  Loader2,
  MapPin,
  AlertCircle,
  Info,
} from "lucide-react";
import Link from "next/link";

interface Course {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string;
  par: number;
  course_rating: number | null;
  slope_rating: number | null;
  latitude: number | null;
  longitude: number | null;
  hole_data: any;
  confirmation_count: number;
  required_confirmations: number;
  is_verified: boolean;
}

export default function ConfirmCoursePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const supabase = createClient();
  const { user } = useUser();
  const [course, setCourse] = useState<Course | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  const [confirmation, setConfirmation] = useState({
    confirmed_fields: {
      dimensions: false,
      tee_locations: false,
      green_locations: false,
      pars: false,
      hazards: false,
      address: false,
      ratings: false,
    },
    confidence: 3,
    has_discrepancies: false,
    discrepancy_details: "",
    notes: "",
  });

  const fetchCourse = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from("courses")
        .select("*")
        .eq("id", id)
        .single();

      if (error) throw error;
      setCourse(data);

      // Check if user already confirmed this course
      if (user) {
        const { data: existing } = await supabase
          .from("course_confirmations")
          .select("*")
          .eq("course_id", id)
          .eq("confirmer_id", user.id)
          .single();

        if (existing) {
          setConfirmation({
            confirmed_fields: existing.confirmed_fields || confirmation.confirmed_fields,
            confidence: existing.confidence || 3,
            has_discrepancies: existing.has_discrepancies || false,
            discrepancy_details: existing.discrepancy_details || "",
            notes: existing.notes || "",
          });
        }
      }
    } catch (err) {
      console.error("Error fetching course:", err);
    } finally {
      setLoading(false);
    }
  }, [supabase, id, user]);

  useEffect(() => {
    if (!user) {
      router.push("/login");
      return;
    }
    fetchCourse();
  }, [user, router, fetchCourse]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !course) return;

    setSubmitting(true);

    try {
      const confirmationData = {
        course_id: course.id,
        confirmer_id: user.id,
        confirmed_fields: confirmation.confirmed_fields,
        confidence: confirmation.confidence,
        has_discrepancies: confirmation.has_discrepancies,
        discrepancy_details: confirmation.has_discrepancies
          ? confirmation.discrepancy_details
          : null,
        notes: confirmation.notes || null,
      };

      const { error } = await supabase
        .from("course_confirmations")
        .upsert(confirmationData, {
          onConflict: "course_id,confirmer_id,contribution_id",
        });

      if (error) throw error;

      setSuccess(true);
      setTimeout(() => {
        router.push(`/courses/${course.id}`);
      }, 2000);
    } catch (err: any) {
      console.error("Error submitting confirmation:", err);
      alert(err.message || "Failed to submit confirmation");
    } finally {
      setSubmitting(false);
    }
  };

  if (loading || !course) {
    return (
      <div className="flex justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  if (success) {
    return (
      <div className="max-w-2xl mx-auto py-12">
        <Card className="p-8 text-center">
          <CheckCircle2 className="w-16 h-16 text-accent-green mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-foreground mb-2">
            Confirmation Submitted!
          </h2>
          <p className="text-foreground-muted mb-6">
            Thank you for confirming this course! Your confirmation helps verify
            the course data for everyone.
          </p>
          <Button onClick={() => router.push(`/courses/${course.id}`)}>
            View Course
          </Button>
        </Card>
      </div>
    );
  }

  const atLeastOneFieldConfirmed = Object.values(
    confirmation.confirmed_fields
  ).some((v) => v === true);

  return (
    <div className="max-w-4xl mx-auto py-8">
      <div className="mb-6">
        <Link
          href={`/courses/${course.id}`}
          className="text-foreground-muted hover:text-foreground inline-flex items-center gap-1"
        >
          ← Back to Course
        </Link>
        <h1 className="text-3xl font-bold text-foreground mt-4">
          Confirm Course Data
        </h1>
        <p className="text-foreground-muted mt-2">
          Help verify the course information by confirming what matches your
          knowledge of this course.
        </p>
      </div>

      {/* Course Info */}
      <Card className="p-6 mb-6">
        <h2 className="text-xl font-semibold text-foreground mb-4">
          {course.name}
        </h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <div className="text-sm text-foreground-muted">Location</div>
            <div className="text-foreground">
              {[course.city, course.state, course.country]
                .filter(Boolean)
                .join(", ")}
            </div>
          </div>
          <div>
            <div className="text-sm text-foreground-muted">Par</div>
            <div className="text-foreground">{course.par}</div>
          </div>
          {course.course_rating && (
            <div>
              <div className="text-sm text-foreground-muted">Rating</div>
              <div className="text-foreground">{course.course_rating}</div>
            </div>
          )}
          {course.slope_rating && (
            <div>
              <div className="text-sm text-foreground-muted">Slope</div>
              <div className="text-foreground">{course.slope_rating}</div>
            </div>
          )}
        </div>
        <div className="mt-4">
          <div className="text-sm text-foreground-muted mb-2">
            Verification Status
          </div>
          <div className="flex items-center gap-2">
            {course.is_verified ? (
              <>
                <CheckCircle2 className="w-5 h-5 text-accent-green" />
                <span className="text-accent-green font-medium">Verified</span>
              </>
            ) : (
              <>
                <AlertCircle className="w-5 h-5 text-accent-amber" />
                <span className="text-accent-amber">
                  {course.confirmation_count} / {course.required_confirmations}{" "}
                  confirmations
                </span>
              </>
            )}
          </div>
        </div>
      </Card>

      <Card className="p-6 mb-6 bg-accent-blue/10 border-accent-blue/20">
        <div className="flex items-start gap-3">
          <Info className="w-5 h-5 text-accent-blue mt-0.5" />
          <div className="text-sm text-foreground-muted">
            <p className="font-medium text-foreground mb-1">
              How to confirm a course:
            </p>
            <ul className="list-disc list-inside space-y-1">
              <li>
                Check each field that matches your knowledge of the course
              </li>
              <li>
                If you find discrepancies, mark them and provide details
              </li>
              <li>
                Set your confidence level (1 = not sure, 5 = very confident)
              </li>
              <li>
                Courses need {course.required_confirmations} confirmations
                without discrepancies to be verified
              </li>
            </ul>
          </div>
        </div>
      </Card>

      <form onSubmit={handleSubmit} className="space-y-6">
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            What matches?
          </h2>
          <div className="space-y-3">
            {Object.entries(confirmation.confirmed_fields).map(([key, value]) => (
              <label
                key={key}
                className="flex items-center gap-3 p-3 rounded-lg hover:bg-background-secondary cursor-pointer"
              >
                <input
                  type="checkbox"
                  checked={value}
                  onChange={(e) =>
                    setConfirmation({
                      ...confirmation,
                      confirmed_fields: {
                        ...confirmation.confirmed_fields,
                        [key]: e.target.checked,
                      },
                    })
                  }
                  className="w-5 h-5 rounded border-background-tertiary text-accent-green focus:ring-accent-green"
                />
                <span className="text-foreground capitalize">
                  {key.replace("_", " ")}
                </span>
              </label>
            ))}
          </div>
        </Card>

        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Confidence Level
          </h2>
          <div className="space-y-3">
            <label className="block text-sm font-medium text-foreground mb-2">
              How confident are you in your confirmation? (1-5)
            </label>
            <div className="flex gap-2">
              {[1, 2, 3, 4, 5].map((level) => (
                <button
                  key={level}
                  type="button"
                  onClick={() =>
                    setConfirmation({ ...confirmation, confidence: level })
                  }
                  className={`flex-1 py-2 rounded-lg border-2 transition-colors ${
                    confirmation.confidence === level
                      ? "border-accent-green bg-accent-green/20 text-accent-green"
                      : "border-background-tertiary text-foreground-muted hover:border-background-tertiary/50"
                  }`}
                >
                  {level}
                </button>
              ))}
            </div>
            <div className="text-sm text-foreground-muted mt-2">
              {confirmation.confidence === 1 && "Not sure at all"}
              {confirmation.confidence === 2 && "Somewhat unsure"}
              {confirmation.confidence === 3 && "Moderately confident"}
              {confirmation.confidence === 4 && "Very confident"}
              {confirmation.confidence === 5 && "Absolutely certain"}
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Discrepancies
          </h2>
          <label className="flex items-center gap-3 mb-4">
            <input
              type="checkbox"
              checked={confirmation.has_discrepancies}
              onChange={(e) =>
                setConfirmation({
                  ...confirmation,
                  has_discrepancies: e.target.checked,
                })
              }
              className="w-5 h-5 rounded border-background-tertiary text-accent-green focus:ring-accent-green"
            />
            <span className="text-foreground">
              I found discrepancies with this course data
            </span>
          </label>
          {confirmation.has_discrepancies && (
            <div>
              <label className="block text-sm font-medium text-foreground mb-2">
                Please describe the discrepancies:
              </label>
              <textarea
                value={confirmation.discrepancy_details}
                onChange={(e) =>
                  setConfirmation({
                    ...confirmation,
                    discrepancy_details: e.target.value,
                  })
                }
                className="w-full p-3 bg-background-secondary border border-background-tertiary rounded-lg text-foreground placeholder-foreground-muted resize-none"
                rows={4}
                placeholder="Example: The par for hole 5 is listed as 4, but it's actually a par 3..."
              />
            </div>
          )}
        </Card>

        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Additional Notes (Optional)
          </h2>
          <textarea
            value={confirmation.notes}
            onChange={(e) =>
              setConfirmation({ ...confirmation, notes: e.target.value })
            }
            className="w-full p-3 bg-background-secondary border border-background-tertiary rounded-lg text-foreground placeholder-foreground-muted resize-none"
            rows={4}
            placeholder="Any additional information about this course..."
          />
        </Card>

        <div className="flex gap-4">
          <Button
            type="submit"
            disabled={submitting || !atLeastOneFieldConfirmed}
            className="flex items-center gap-2"
          >
            {submitting ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                Submitting...
              </>
            ) : (
              <>
                <CheckCircle2 className="w-4 h-4" />
                Submit Confirmation
              </>
            )}
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={() => router.push(`/courses/${course.id}`)}
          >
            Cancel
          </Button>
        </div>
      </form>
    </div>
  );
}
