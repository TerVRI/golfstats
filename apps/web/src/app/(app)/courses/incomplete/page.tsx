"use client";

import { useEffect, useState, useCallback } from "react";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { fetchIncompleteCourses, IncompleteCourse } from "@/lib/incomplete-courses";
import { Search, MapPin, AlertCircle, CheckCircle, Loader2, Navigation, Award } from "lucide-react";
import Link from "next/link";

export default function IncompleteCoursesPage() {
  const { user } = useUser();
  const [courses, setCourses] = useState<IncompleteCourse[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<{
    country?: string;
    minPriority?: number;
  }>({});

  const loadCourses = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchIncompleteCourses({
        limit: 100,
        ...filter,
      });
      setCourses(data);
    } catch (err) {
      console.error("Error loading incomplete courses:", err);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => {
    loadCourses();
  }, [loadCourses]);

  const filteredCourses = courses.filter((course) => {
    if (search) {
      const searchLower = search.toLowerCase();
      return (
        course.name.toLowerCase().includes(searchLower) ||
        course.city?.toLowerCase().includes(searchLower) ||
        course.country.toLowerCase().includes(searchLower) ||
        course.address?.toLowerCase().includes(searchLower)
      );
    }
    return true;
  });

  const getPriorityBadge = (priority: number) => {
    if (priority >= 10) {
      return <Badge variant="default" className="bg-green-500">High Priority</Badge>;
    } else if (priority >= 7) {
      return <Badge variant="default" className="bg-yellow-500">Medium Priority</Badge>;
    } else {
      return <Badge variant="outline">Low Priority</Badge>;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "incomplete":
        return <Badge variant="outline" className="border-orange-500 text-orange-500">Incomplete</Badge>;
      case "needs_location":
        return <Badge variant="outline" className="border-red-500 text-red-500">Needs Location</Badge>;
      case "needs_verification":
        return <Badge variant="outline" className="border-blue-500 text-blue-500">Needs Verification</Badge>;
      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Incomplete Courses</h1>
          <p className="text-foreground-muted">Help complete courses by adding missing information</p>
        </div>
        <div className="flex gap-2">
          <Link href="/courses/incomplete/leaderboard">
            <Button variant="outline" className="flex items-center gap-2">
              <Award className="w-4 h-4" />
              Leaderboard
            </Button>
          </Link>
        </div>
      </div>

      {/* Info Banner */}
      <Card className="p-4 bg-blue-50 dark:bg-blue-950 border-blue-200 dark:border-blue-800">
        <div className="flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-blue-600 dark:text-blue-400 mt-0.5" />
          <div className="flex-1">
            <h3 className="font-semibold text-blue-900 dark:text-blue-100 mb-1">
              Help Build the Golf Course Database
            </h3>
            <p className="text-sm text-blue-800 dark:text-blue-200">
              These courses need location information. Complete them to earn badges and climb the leaderboard!
            </p>
          </div>
        </div>
      </Card>

      {/* Search and Filters */}
      <Card className="p-4">
        <div className="space-y-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground-muted" />
            <Input
              placeholder="Search by name, city, or address..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-10"
            />
          </div>
          <div className="flex gap-2 flex-wrap">
            <Button
              size="sm"
              variant={filter.minPriority === 10 ? "default" : "outline"}
              onClick={() => setFilter({ ...filter, minPriority: filter.minPriority === 10 ? undefined : 10 })}
            >
              High Priority
            </Button>
            <Button
              size="sm"
              variant={filter.minPriority === 7 ? "default" : "outline"}
              onClick={() => setFilter({ ...filter, minPriority: filter.minPriority === 7 ? undefined : 7 })}
            >
              Medium Priority
            </Button>
            <Button
              size="sm"
              variant={filter.minPriority === undefined ? "default" : "outline"}
              onClick={() => setFilter({ ...filter, minPriority: undefined })}
            >
              All Priorities
            </Button>
          </div>
        </div>
      </Card>

      {/* Course List */}
      {loading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
        </div>
      ) : filteredCourses.length === 0 ? (
        <Card className="p-12 text-center">
          <div className="text-foreground-muted">
            <MapPin className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p>No incomplete courses found</p>
            <p className="text-sm mt-2">All courses are complete! Great job! 🎉</p>
          </div>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {filteredCourses.map((course) => (
            <Card key={course.id} className="p-4 hover:bg-background-secondary/50 transition-colors">
              <div className="flex justify-between items-start mb-3">
                <div className="flex-1">
                  <h3 className="font-semibold text-foreground text-lg">{course.name}</h3>
                  {(course.city || course.state || course.country) && (
                    <p className="text-foreground-muted text-sm flex items-center gap-1 mt-1">
                      <MapPin className="w-3 h-3" />
                      {[course.city, course.state, course.country].filter(Boolean).join(", ")}
                    </p>
                  )}
                  {course.address && (
                    <p className="text-foreground-muted text-xs mt-1">{course.address}</p>
                  )}
                </div>
                <div className="flex flex-col gap-2 items-end">
                  {getPriorityBadge(course.completion_priority)}
                  {getStatusBadge(course.status)}
                </div>
              </div>

              {/* Missing Fields */}
              {course.missing_fields && course.missing_fields.length > 0 && (
                <div className="mb-3">
                  <p className="text-xs text-foreground-muted mb-1">Missing:</p>
                  <div className="flex flex-wrap gap-1">
                    {course.missing_fields.map((field) => (
                      <Badge key={field} variant="outline" className="text-xs">
                        {field}
                      </Badge>
                    ))}
                  </div>
                </div>
              )}

              {/* Contact Info */}
              <div className="flex gap-4 text-sm mb-3">
                {course.phone && (
                  <div>
                    <span className="text-foreground-muted">Phone:</span>
                    <span className="ml-2 text-foreground">{course.phone}</span>
                  </div>
                )}
                {course.website && (
                  <div>
                    <span className="text-foreground-muted">Website:</span>
                    <a
                      href={course.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="ml-2 text-accent-blue hover:underline"
                    >
                      Visit
                    </a>
                  </div>
                )}
              </div>

              {/* Actions */}
              <div className="flex gap-2">
                <Link href={`/courses/incomplete/${course.id}/complete`} className="flex-1">
                  <Button className="w-full" size="sm">
                    <Navigation className="w-4 h-4 mr-2" />
                    Complete Course
                  </Button>
                </Link>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* Stats */}
      {!loading && filteredCourses.length > 0 && (
        <Card className="p-4">
          <div className="text-sm text-foreground-muted">
            Showing {filteredCourses.length} of {courses.length} incomplete courses
          </div>
        </Card>
      )}
    </div>
  );
}
