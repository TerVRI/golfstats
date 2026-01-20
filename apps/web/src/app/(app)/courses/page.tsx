"use client";

import { useEffect, useState, useCallback } from "react";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { Search, MapPin, Star, ThumbsUp, Clock, Loader2, Plus, Trophy } from "lucide-react";
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
}

export default function CoursesPage() {
  const supabase = createClient();
  const { user } = useUser();
  const [courses, setCourses] = useState<Course[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [userCountry, setUserCountry] = useState<string | null>(null);
  const [showAllCountries, setShowAllCountries] = useState(false);

  // Detect user's country on mount
  useEffect(() => {
    import("@/lib/geolocation").then(({ getUserCountry }) => {
      getUserCountry().then((location) => {
        if (location) {
          setUserCountry(location.country);
        }
      });
    });
  }, []);

  const fetchCourses = useCallback(async () => {
    setLoading(true);
    try {
      let query = supabase
        .from("courses")
        .select("id, name, city, state, country, par, course_rating, slope_rating, avg_rating, review_count, latitude, longitude")
        .order("review_count", { ascending: false })
        .limit(50);

      // Filter by country by default (unless searching or showing all)
      if (!search && !showAllCountries && userCountry) {
        query = query.eq("country", userCountry);
      }

      if (search) {
        query = query.ilike("name", `%${search}%`);
      }

      const { data, error } = await query;
      if (error) throw error;
      setCourses(data || []);
    } catch (err) {
      console.error("Error fetching courses:", err);
    } finally {
      setLoading(false);
    }
  }, [supabase, search, userCountry, showAllCountries]);

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchCourses();
    }, 300);
    return () => clearTimeout(timer);
  }, [search, fetchCourses]);

  const renderStars = (rating: number | null) => {
    if (!rating) return <span className="text-foreground-muted text-sm">No reviews</span>;
    return (
      <div className="flex items-center gap-1">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            className={`w-4 h-4 ${star <= rating ? "fill-accent-amber text-accent-amber" : "text-background-tertiary"}`}
          />
        ))}
        <span className="text-foreground-muted text-sm ml-1">({rating.toFixed(1)})</span>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Golf Courses</h1>
          <p className="text-foreground-muted">Discover and review courses</p>
        </div>
        <div className="flex gap-2">
          <Link href="/courses/osm-visualization">
            <Button variant="outline" className="flex items-center gap-2">
              <MapPin className="w-4 h-4" />
              OSM Map
            </Button>
          </Link>
          <Link href="/courses/leaderboard">
            <Button variant="outline" className="flex items-center gap-2">
              <Trophy className="w-4 h-4" />
              Leaderboard
            </Button>
          </Link>
          <Link href="/courses/contribute">
            <Button className="flex items-center gap-2">
              <Plus className="w-4 h-4" />
              Contribute Course
            </Button>
          </Link>
        </div>
      </div>

      {/* Search and Filters */}
      <Card className="p-4">
        <div className="space-y-3">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground-muted" />
          <Input
            placeholder="Search courses by name..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-10"
          />
          </div>
          {userCountry && (
            <div className="flex items-center gap-2 text-sm">
              <span className="text-foreground-muted">
                Showing courses in: <strong className="text-foreground">{userCountry}</strong>
              </span>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => setShowAllCountries(!showAllCountries)}
                className="h-auto py-1"
              >
                {showAllCountries ? "Show local only" : "Show all countries"}
              </Button>
            </div>
          )}
        </div>
      </Card>

      {/* Course List */}
      {loading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
        </div>
      ) : courses.length === 0 ? (
        <Card className="p-12 text-center">
          <div className="text-foreground-muted">
            <MapPin className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p>No courses found</p>
            <p className="text-sm mt-2">Try a different search or add a new course</p>
          </div>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {courses.map((course) => (
            <Link key={course.id} href={`/courses/${course.id}`}>
              <Card className="p-4 hover:bg-background-secondary/50 transition-colors cursor-pointer h-full">
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <h3 className="font-semibold text-foreground text-lg">{course.name}</h3>
                    {(course.city || course.state) && (
                      <p className="text-foreground-muted text-sm flex items-center gap-1 mt-1">
                        <MapPin className="w-3 h-3" />
                        {[course.city, course.state, course.country].filter(Boolean).join(", ")}
                      </p>
                    )}
                  </div>
                  <div className="text-right">
                    {renderStars(course.avg_rating)}
                    {course.review_count > 0 && (
                      <p className="text-xs text-foreground-muted mt-1">{course.review_count} reviews</p>
                    )}
                  </div>
                </div>

                <div className="flex gap-4 mt-4 text-sm">
                  <div>
                    <span className="text-foreground-muted">Par</span>
                    <span className="ml-2 font-medium text-foreground">{course.par}</span>
                  </div>
                  <div>
                    <span className="text-foreground-muted">Rating</span>
                    <span className="ml-2 font-medium text-foreground">{course.course_rating}</span>
                  </div>
                  <div>
                    <span className="text-foreground-muted">Slope</span>
                    <span className="ml-2 font-medium text-foreground">{course.slope_rating}</span>
                  </div>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
