"use client";

import { useEffect, useState, useCallback, use } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { fetchWeather, WeatherForecast } from "@roundcaddy/shared";
import { CourseDiscussions } from "@/components/course-discussions";
import { CourseVisualizer } from "@/components/course-visualizer";
import { CourseSVGVisualizer } from "@/components/course-svg-visualizer";
import {
  MapPin,
  Star,
  ThumbsUp,
  Phone,
  Globe,
  Wind,
  Droplets,
  Sun,
  Cloud,
  ChevronLeft,
  Loader2,
  Send,
  CheckCircle2,
} from "lucide-react";
import Link from "next/link";

interface Course {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string | null;
  par: number;
  course_rating: number;
  slope_rating: number;
  avg_rating: number | null;
  review_count: number;
  latitude: number | null;
  longitude: number | null;
  phone: string | null;
  website: string | null;
  hole_data: any;
  is_verified: boolean;
  confirmation_count: number;
  required_confirmations: number;
}

interface Review {
  id: string;
  user_id: string;
  rating: number;
  title: string | null;
  review_text: string | null;
  conditions_rating: number | null;
  pace_rating: number | null;
  value_rating: number | null;
  difficulty: string | null;
  would_recommend: boolean;
  played_at: string | null;
  helpful_count: number;
  created_at: string;
  profiles?: { full_name: string | null; avatar_url: string | null };
}

export default function CourseDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supabase = createClient();
  const { user } = useUser();
  const [course, setCourse] = useState<Course | null>(null);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [weather, setWeather] = useState<WeatherForecast | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [submittingReview, setSubmittingReview] = useState(false);
  const [visualizationMode, setVisualizationMode] = useState<"map" | "schematic">("map");

  // Review form
  const [newReview, setNewReview] = useState({
    rating: 5,
    title: "",
    review_text: "",
    conditions_rating: 4,
    pace_rating: 4,
    value_rating: 4,
    difficulty: "moderate",
  });

  const fetchCourse = useCallback(async () => {
    try {
      setError(null);
      const { data, error } = await supabase
        .from("courses")
        .select("*, confirmation_count, required_confirmations, is_verified")
        .eq("id", id)
        .single();
      if (error) throw error;
      if (!data) {
        setError("Course not found");
        setLoading(false);
        return;
      }
      setCourse(data);

      // Fetch weather if coordinates exist
      if (data.latitude && data.longitude) {
        const weatherData = await fetchWeather(data.latitude, data.longitude);
        setWeather(weatherData);
      }
    } catch (err) {
      console.error("Error fetching course:", err);
      setError(err instanceof Error ? err.message : "Failed to load course");
      setLoading(false);
    }
  }, [supabase, id]);

  const fetchReviews = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from("course_reviews")
        .select("*, profiles(full_name, avatar_url)")
        .eq("course_id", id)
        .order("created_at", { ascending: false });
      if (error) throw error;
      setReviews(data || []);
    } catch (err) {
      console.error("Error fetching reviews:", err);
    } finally {
      setLoading(false);
    }
  }, [supabase, id]);

  useEffect(() => {
    fetchCourse();
    fetchReviews();
  }, [fetchCourse, fetchReviews]);

  const submitReview = async () => {
    if (!user || !course) return;
    setSubmittingReview(true);

    try {
      const { error } = await supabase.from("course_reviews").upsert({
        course_id: course.id,
        user_id: user.id,
        rating: newReview.rating,
        title: newReview.title || null,
        review_text: newReview.review_text || null,
        conditions_rating: newReview.conditions_rating,
        pace_rating: newReview.pace_rating,
        value_rating: newReview.value_rating,
        difficulty: newReview.difficulty,
        would_recommend: newReview.rating >= 3,
        played_at: new Date().toISOString().split("T")[0],
      });

      if (error) throw error;

      // Reset form and refresh
      setNewReview({
        rating: 5,
        title: "",
        review_text: "",
        conditions_rating: 4,
        pace_rating: 4,
        value_rating: 4,
        difficulty: "moderate",
      });
      fetchReviews();
      fetchCourse();
    } catch (err) {
      console.error("Error submitting review:", err);
    } finally {
      setSubmittingReview(false);
    }
  };

  const renderStars = (rating: number, interactive = false, onChange?: (r: number) => void) => {
    return (
      <div className="flex items-center gap-1">
        {[1, 2, 3, 4, 5].map((star) => (
          <button
            key={star}
            type="button"
            disabled={!interactive}
            onClick={() => onChange?.(star)}
            className={interactive ? "cursor-pointer hover:scale-110 transition-transform" : ""}
          >
            <Star
              className={`w-5 h-5 ${
                star <= rating ? "fill-accent-amber text-accent-amber" : "text-background-tertiary"
              }`}
            />
          </button>
        ))}
      </div>
    );
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  if (error || !course) {
    return (
      <div className="space-y-6">
        <Link href="/courses" className="inline-flex items-center text-foreground-muted hover:text-foreground transition-colors">
          <ChevronLeft className="w-4 h-4" />
          Back to Courses
        </Link>
        <Card className="p-12 text-center">
          <div className="text-foreground-muted">
            <MapPin className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p className="text-lg font-semibold mb-2">{error || "Course not found"}</p>
            <p className="text-sm mt-2">The course you're looking for doesn't exist or has been removed.</p>
            <Link href="/courses">
              <Button className="mt-4">Browse All Courses</Button>
            </Link>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Back Link */}
      <Link href="/courses" className="inline-flex items-center text-foreground-muted hover:text-foreground transition-colors">
        <ChevronLeft className="w-4 h-4" />
        Back to Courses
      </Link>

      {/* Course Header */}
      <div className="flex flex-col lg:flex-row gap-6">
        <Card className="flex-1 p-6">
          <div className="flex justify-between items-start">
            <div>
              <h1 className="text-2xl font-bold text-foreground">{course.name}</h1>
              {(course.city || course.state) && (
                <p className="text-foreground-muted flex items-center gap-1 mt-1">
                  <MapPin className="w-4 h-4" />
                  {[course.city, course.state, course.country].filter(Boolean).join(", ")}
                </p>
              )}
            </div>
            <div className="text-right">
              {renderStars(course.avg_rating || 0)}
              <p className="text-sm text-foreground-muted mt-1">{course.review_count} reviews</p>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4 mt-6">
            <div className="text-center p-3 bg-background-secondary rounded-lg">
              <div className="text-2xl font-bold text-foreground">{course.par}</div>
              <div className="text-sm text-foreground-muted">Par</div>
            </div>
            <div className="text-center p-3 bg-background-secondary rounded-lg">
              <div className="text-2xl font-bold text-foreground">{course.course_rating}</div>
              <div className="text-sm text-foreground-muted">Rating</div>
            </div>
            <div className="text-center p-3 bg-background-secondary rounded-lg">
              <div className="text-2xl font-bold text-foreground">{course.slope_rating}</div>
              <div className="text-sm text-foreground-muted">Slope</div>
            </div>
          </div>

          {/* Contact Info */}
          <div className="flex gap-4 mt-6 flex-wrap">
            {course.phone && (
              <a href={`tel:${course.phone}`} className="flex items-center gap-2 text-foreground-muted hover:text-foreground">
                <Phone className="w-4 h-4" />
                {course.phone}
              </a>
            )}
            {course.website && (
              <a
                href={course.website}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-foreground-muted hover:text-foreground"
              >
                <Globe className="w-4 h-4" />
                Website
              </a>
            )}
          </div>

          {/* Confirm Course Button */}
          {user && (
            <div className="mt-6">
              <Link href={`/courses/confirm/${course.id}`}>
                <Button variant="outline" className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4" />
                  {course.is_verified ? "Re-confirm Course" : "Confirm Course Data"}
                </Button>
              </Link>
              {!course.is_verified && (
                <p className="text-xs text-foreground-muted mt-2">
                  Help verify this course by confirming the data matches your knowledge
                </p>
              )}
            </div>
          )}
        </Card>

        {/* Weather Card */}
        {weather && (
          <Card className="lg:w-80 p-6">
            <h3 className="font-semibold text-foreground mb-4">Current Weather</h3>
            <div className="flex items-center justify-between mb-4">
              <div className="text-4xl">{weather.current.icon}</div>
              <div className="text-right">
                <div className="text-3xl font-bold text-foreground">{weather.current.temperature}°F</div>
                <div className="text-foreground-muted text-sm">{weather.current.conditions}</div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="flex items-center gap-2">
                <Wind className="w-4 h-4 text-foreground-muted" />
                <span className="text-foreground">{weather.current.windSpeed} mph {weather.current.windDirectionLabel}</span>
              </div>
              <div className="flex items-center gap-2">
                <Droplets className="w-4 h-4 text-foreground-muted" />
                <span className="text-foreground">{weather.current.humidity}%</span>
              </div>
              <div className="flex items-center gap-2">
                <Cloud className="w-4 h-4 text-foreground-muted" />
                <span className="text-foreground">{weather.current.precipitationProbability}% rain</span>
              </div>
              <div className="flex items-center gap-2">
                <Sun className="w-4 h-4 text-foreground-muted" />
                <span className="text-foreground">UV {weather.current.uvIndex}</span>
              </div>
            </div>
            <div className={`mt-4 p-2 rounded text-center text-sm font-medium ${
              weather.current.isGoodForGolf 
                ? "bg-accent-green/20 text-accent-green" 
                : "bg-accent-amber/20 text-accent-amber"
            }`}>
              {weather.current.isGoodForGolf ? "☀️ Great day for golf!" : "⚠️ Check conditions"}
            </div>
          </Card>
        )}
      </div>

      {/* Course Visualization */}
      <Card className="p-6">
        {course.hole_data && Array.isArray(course.hole_data) && course.hole_data.length > 0 ? (
          <>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-2xl font-bold text-foreground">Course Layout</h2>
            <div className="flex items-center gap-2">
              <Button
                size="sm"
                variant={visualizationMode === "map" ? "default" : "outline"}
                onClick={() => setVisualizationMode("map")}
              >
                Map View
              </Button>
              <Button
                size="sm"
                variant={visualizationMode === "schematic" ? "default" : "outline"}
                onClick={() => setVisualizationMode("schematic")}
              >
                Schematic View
              </Button>
            </div>
          </div>
          {visualizationMode === "map" ? (
            <CourseVisualizer
              holeData={course.hole_data}
              center={
                course.latitude && course.longitude
                  ? [course.latitude, course.longitude]
                  : undefined
              }
              zoom={15}
              showSatellite={false}
              mode="view"
            />
          ) : (
            <CourseSVGVisualizer
              holeData={course.hole_data}
              mode="hole"
            />
          )}
          </>
        ) : (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">🗺️</div>
            <h3 className="text-xl font-semibold text-foreground mb-2">Visualization Not Available</h3>
            <p className="text-foreground-muted">
              This course doesn't have hole-by-hole layout data yet.
            </p>
          </div>
        )}
      </Card>

      {/* Write Review */}
      {user && (
        <Card className="p-6">
          <h3 className="font-semibold text-foreground mb-4">Write a Review</h3>
          <div className="space-y-4">
            <div className="flex items-center gap-4">
              <span className="text-foreground-muted">Overall Rating:</span>
              {renderStars(newReview.rating, true, (r) => setNewReview((prev) => ({ ...prev, rating: r })))}
            </div>
            <Input
              placeholder="Review title (optional)"
              value={newReview.title}
              onChange={(e) => setNewReview((prev) => ({ ...prev, title: e.target.value }))}
            />
            <textarea
              className="w-full p-3 bg-background-secondary border border-background-tertiary rounded-xl text-foreground placeholder-foreground-muted resize-none"
              rows={4}
              placeholder="Share your experience..."
              value={newReview.review_text}
              onChange={(e) => setNewReview((prev) => ({ ...prev, review_text: e.target.value }))}
            />
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <label className="text-sm text-foreground-muted">Conditions</label>
                {renderStars(newReview.conditions_rating, true, (r) =>
                  setNewReview((prev) => ({ ...prev, conditions_rating: r }))
                )}
              </div>
              <div>
                <label className="text-sm text-foreground-muted">Pace of Play</label>
                {renderStars(newReview.pace_rating, true, (r) =>
                  setNewReview((prev) => ({ ...prev, pace_rating: r }))
                )}
              </div>
              <div>
                <label className="text-sm text-foreground-muted">Value</label>
                {renderStars(newReview.value_rating, true, (r) =>
                  setNewReview((prev) => ({ ...prev, value_rating: r }))
                )}
              </div>
              <div>
                <label className="text-sm text-foreground-muted">Difficulty</label>
                <Select
                  value={newReview.difficulty}
                  onChange={(e) => setNewReview((prev) => ({ ...prev, difficulty: e.target.value }))}
                  options={[
                    { value: "easy", label: "Easy" },
                    { value: "moderate", label: "Moderate" },
                    { value: "difficult", label: "Difficult" },
                    { value: "very_difficult", label: "Very Difficult" },
                  ]}
                />
              </div>
            </div>
            <Button onClick={submitReview} disabled={submittingReview} className="flex items-center gap-2">
              {submittingReview ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              Submit Review
            </Button>
          </div>
        </Card>
      )}

      {/* Reviews List */}
      <div>
        <h3 className="font-semibold text-foreground text-lg mb-4">Reviews ({reviews.length})</h3>
        {reviews.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-foreground-muted">No reviews yet. Be the first to review!</p>
          </Card>
        ) : (
          <div className="space-y-4">
            {reviews.map((review) => (
              <Card key={review.id} className="p-6">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <div className="font-medium text-foreground">
                      {review.profiles?.full_name || "Anonymous Golfer"}
                    </div>
                    <div className="text-sm text-foreground-muted">
                      {new Date(review.created_at).toLocaleDateString()}
                    </div>
                  </div>
                  {renderStars(review.rating)}
                </div>
                {review.title && <h4 className="font-semibold text-foreground mb-2">{review.title}</h4>}
                {review.review_text && <p className="text-foreground-muted mb-4">{review.review_text}</p>}
                <div className="flex gap-4 text-sm">
                  {review.conditions_rating && (
                    <div className="flex items-center gap-1">
                      <span className="text-foreground-muted">Conditions:</span>
                      {renderStars(review.conditions_rating)}
                    </div>
                  )}
                  {review.difficulty && (
                    <div>
                      <span className="text-foreground-muted">Difficulty:</span>
                      <span className="ml-1 text-foreground capitalize">{review.difficulty.replace("_", " ")}</span>
                    </div>
                  )}
                </div>
                {review.would_recommend && (
                  <div className="mt-3 flex items-center gap-1 text-accent-green text-sm">
                    <ThumbsUp className="w-4 h-4" />
                    Would recommend
                  </div>
                )}
              </Card>
            ))}
          </div>
        )}

        {/* Course Discussions */}
        <div className="mt-8">
          <h2 className="text-2xl font-bold text-foreground mb-4">Discussions</h2>
          <CourseDiscussions courseId={course.id} />
        </div>
      </div>
    </div>
  );
}
