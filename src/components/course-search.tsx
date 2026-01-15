"use client";

import { useState, useEffect, useRef } from "react";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";
import { Search, MapPin, Loader2 } from "lucide-react";

interface Course {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string;
  course_rating: number | null;
  slope_rating: number | null;
  par: number;
}

interface CourseSearchProps {
  onSelect: (course: Course) => void;
  value?: string;
  onChange?: (value: string) => void;
}

export function CourseSearch({ onSelect, value = "", onChange }: CourseSearchProps) {
  const supabase = createClient();
  const [query, setQuery] = useState(value);
  const [courses, setCourses] = useState<Course[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setQuery(value);
  }, [value]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    const searchCourses = async () => {
      if (query.length < 2) {
        setCourses([]);
        return;
      }

      setIsLoading(true);
      try {
        const { data, error } = await supabase
          .from("courses")
          .select("*")
          .ilike("name", `%${query}%`)
          .limit(10);

        if (error) throw error;
        setCourses(data || []);
      } catch (err) {
        console.error("Error searching courses:", err);
      } finally {
        setIsLoading(false);
      }
    };

    const debounce = setTimeout(searchCourses, 300);
    return () => clearTimeout(debounce);
  }, [query, supabase]);

  const handleSelect = (course: Course) => {
    setQuery(course.name);
    onChange?.(course.name);
    onSelect(course);
    setIsOpen(false);
  };

  return (
    <div ref={wrapperRef} className="relative">
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground-muted" />
        <input
          type="text"
          placeholder="Search courses..."
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            onChange?.(e.target.value);
            setIsOpen(true);
          }}
          onFocus={() => setIsOpen(true)}
          className="w-full pl-10 pr-4 py-2 rounded-lg bg-background-secondary border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green"
        />
        {isLoading && (
          <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-foreground-muted animate-spin" />
        )}
      </div>

      {isOpen && courses.length > 0 && (
        <div className="absolute z-50 w-full mt-2 py-2 bg-background-secondary border border-card-border rounded-lg shadow-xl max-h-64 overflow-y-auto">
          {courses.map((course) => (
            <button
              key={course.id}
              onClick={() => handleSelect(course)}
              className="w-full px-4 py-3 text-left hover:bg-background-tertiary transition-colors"
            >
              <p className="font-medium text-foreground">{course.name}</p>
              <div className="flex items-center gap-2 text-sm text-foreground-muted">
                {(course.city || course.state) && (
                  <span className="flex items-center gap-1">
                    <MapPin className="w-3 h-3" />
                    {[course.city, course.state].filter(Boolean).join(", ")}
                  </span>
                )}
                {course.course_rating && (
                  <span>• Rating: {course.course_rating}</span>
                )}
                {course.slope_rating && (
                  <span>• Slope: {course.slope_rating}</span>
                )}
              </div>
            </button>
          ))}
        </div>
      )}

      {isOpen && query.length >= 2 && courses.length === 0 && !isLoading && (
        <div className="absolute z-50 w-full mt-2 py-4 px-4 bg-background-secondary border border-card-border rounded-lg shadow-xl text-center">
          <p className="text-foreground-muted text-sm">No courses found</p>
          <p className="text-foreground-muted text-xs mt-1">Enter the course details manually below</p>
        </div>
      )}
    </div>
  );
}

