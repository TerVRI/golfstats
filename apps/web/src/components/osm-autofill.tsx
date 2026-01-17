"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { searchOSMCourses, convertOSMCourseToContribution, OSMCourseData } from "@/lib/openstreetmap";
import { Loader2, MapPin, CheckCircle2, AlertCircle } from "lucide-react";

interface OSMAutofillProps {
  onSelect: (data: ReturnType<typeof convertOSMCourseToContribution>) => void;
  initialLat?: number;
  initialLon?: number;
}

export function OSMAutofill({ onSelect, initialLat, initialLon }: OSMAutofillProps) {
  const [loading, setLoading] = useState(false);
  const [courses, setCourses] = useState<OSMCourseData[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [searchLat, setSearchLat] = useState(initialLat?.toString() || "");
  const [searchLon, setSearchLon] = useState(initialLon?.toString() || "");

  const handleSearch = async () => {
    if (!searchLat || !searchLon) {
      setError("Please enter latitude and longitude");
      return;
    }

    const lat = parseFloat(searchLat);
    const lon = parseFloat(searchLon);

    if (isNaN(lat) || isNaN(lon)) {
      setError("Invalid coordinates");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const result = await searchOSMCourses(lat, lon, 5000);
      setCourses(result.courses);
      if (result.courses.length === 0) {
        setError("No courses found in OpenStreetMap near this location");
      }
    } catch (err: any) {
      setError(err.message || "Failed to search OpenStreetMap");
    } finally {
      setLoading(false);
    }
  };

  const handleSelectCourse = (course: OSMCourseData) => {
    const contributionData = convertOSMCourseToContribution(course);
    onSelect(contributionData);
  };

  return (
    <Card className="p-4 space-y-4">
      <div>
        <h3 className="font-semibold text-foreground mb-2">Import from OpenStreetMap</h3>
        <p className="text-sm text-foreground-muted">
          Search for courses in OpenStreetMap to auto-fill basic information
        </p>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="block text-xs text-foreground-muted mb-1">Latitude</label>
          <input
            type="number"
            step="any"
            value={searchLat}
            onChange={(e) => setSearchLat(e.target.value)}
            placeholder="40.7128"
            className="w-full px-3 py-2 bg-background-secondary border border-background-tertiary rounded-lg text-foreground"
          />
        </div>
        <div>
          <label className="block text-xs text-foreground-muted mb-1">Longitude</label>
          <input
            type="number"
            step="any"
            value={searchLon}
            onChange={(e) => setSearchLon(e.target.value)}
            placeholder="-74.0060"
            className="w-full px-3 py-2 bg-background-secondary border border-background-tertiary rounded-lg text-foreground"
          />
        </div>
      </div>

      <Button
        onClick={handleSearch}
        disabled={loading || !searchLat || !searchLon}
        className="w-full"
        size="sm"
      >
        {loading ? (
          <>
            <Loader2 className="w-4 h-4 mr-2 animate-spin" />
            Searching...
          </>
        ) : (
          <>
            <MapPin className="w-4 h-4 mr-2" />
            Search OSM
          </>
        )}
      </Button>

      {error && (
        <div className="p-3 bg-red-500/10 border border-red-500/20 rounded-lg flex items-start gap-2">
          <AlertCircle className="w-4 h-4 text-red-500 mt-0.5" />
          <p className="text-sm text-red-500">{error}</p>
        </div>
      )}

      {courses.length > 0 && (
        <div className="space-y-2">
          <p className="text-sm font-medium text-foreground">
            Found {courses.length} course{courses.length !== 1 ? "s" : ""}:
          </p>
          {courses.map((course) => (
            <button
              key={course.id}
              onClick={() => handleSelectCourse(course)}
              className="w-full p-3 text-left bg-background-secondary hover:bg-background-tertiary rounded-lg border border-background-tertiary transition-colors"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <p className="font-medium text-foreground">{course.name}</p>
                  <div className="flex items-center gap-2 mt-1 text-xs text-foreground-muted">
                    <MapPin className="w-3 h-3" />
                    <span>
                      {course.lat.toFixed(4)}, {course.lon.toFixed(4)}
                    </span>
                  </div>
                  {course.tags["addr:city"] && (
                    <p className="text-xs text-foreground-muted mt-1">
                      {[
                        course.tags["addr:city"],
                        course.tags["addr:state"],
                        course.tags["addr:country"],
                      ]
                        .filter(Boolean)
                        .join(", ")}
                    </p>
                  )}
                </div>
                <CheckCircle2 className="w-5 h-5 text-accent-green" />
              </div>
            </button>
          ))}
        </div>
      )}
    </Card>
  );
}
