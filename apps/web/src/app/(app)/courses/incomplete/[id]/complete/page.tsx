"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { completeIncompleteCourse, geocodeAddress, IncompleteCourse } from "@/lib/incomplete-courses";
import { MapPin, Loader2, Navigation, CheckCircle, AlertCircle } from "lucide-react";
import dynamic from "next/dynamic";

// Dynamically import map component to avoid SSR issues
const MapComponent = dynamic(() => import("@/components/course-completion-map"), {
  ssr: false,
  loading: () => <div className="h-[400px] bg-background-secondary animate-pulse rounded-lg" />,
});

export default function CompleteCoursePage({ params }: { params: Promise<{ id: string }> }) {
  const router = useRouter();
  const { user } = useUser();
  const supabase = createClient();
  const [course, setCourse] = useState<IncompleteCourse | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  // Form state
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);
  const [phone, setPhone] = useState("");
  const [website, setWebsite] = useState("");
  const [address, setAddress] = useState("");
  const [geocoding, setGeocoding] = useState(false);

  useEffect(() => {
    async function loadCourse() {
      try {
        const { data, error } = await supabase
          .from("course_contributions")
          .select("*")
          .eq("id", id)
          .in("status", ["incomplete", "needs_location"])
          .single();

        if (error) throw error;
        if (!data) {
          setError("Course not found or already completed");
          return;
        }

        setCourse(data as IncompleteCourse);
        setPhone(data.phone || "");
        setWebsite(data.website || "");
        setAddress(data.address || "");
      } catch (err) {
        console.error("Error loading course:", err);
        setError("Failed to load course");
      } finally {
        setLoading(false);
      }
    }

    loadCourse();
  }, [supabase, id]);

  const handleGeocode = async () => {
    if (!course) return;

    setGeocoding(true);
    try {
      const fullAddress = [
        address || course.address,
        course.city,
        course.state,
        course.country,
      ]
        .filter(Boolean)
        .join(", ");

      const coords = await geocodeAddress(fullAddress);
      if (coords) {
        setLatitude(coords.lat);
        setLongitude(coords.lon);
      } else {
        setError("Could not geocode address. Please place marker manually on map.");
      }
    } catch (err) {
      console.error("Geocoding error:", err);
      setError("Geocoding failed. Please place marker manually on map.");
    } finally {
      setGeocoding(false);
    }
  };

  const handleMapClick = (lat: number, lon: number) => {
    setLatitude(lat);
    setLongitude(lon);
  };

  const handleSubmit = async () => {
    if (!course || !latitude || !longitude) {
      setError("Please provide coordinates (use geocoding or click on map)");
      return;
    }

    if (!user) {
      setError("You must be logged in to complete a course");
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      await completeIncompleteCourse(course.id, {
        latitude,
        longitude,
        geocoded: !!address || !!course.address,
        phone: phone || undefined,
        website: website || undefined,
        address: address || undefined,
      });

      setSuccess(true);
      setTimeout(() => {
        router.push("/courses/incomplete");
      }, 2000);
    } catch (err: any) {
      console.error("Error completing course:", err);
      setError(err.message || "Failed to complete course");
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  if (error && !course) {
    return (
      <div className="space-y-6">
        <Card className="p-6">
          <div className="flex items-center gap-3 text-red-600 dark:text-red-400">
            <AlertCircle className="w-5 h-5" />
            <p>{error}</p>
          </div>
          <Button onClick={() => router.push("/courses/incomplete")} className="mt-4">
            Back to Incomplete Courses
          </Button>
        </Card>
      </div>
    );
  }

  if (!course) return null;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-foreground">Complete Course</h1>
        <p className="text-foreground-muted">Add location and missing information</p>
      </div>

      {/* Success Message */}
      {success && (
        <Card className="p-4 bg-green-50 dark:bg-green-950 border-green-200 dark:border-green-800">
          <div className="flex items-center gap-3 text-green-600 dark:text-green-400">
            <CheckCircle className="w-5 h-5" />
            <p>Course completed successfully! Redirecting...</p>
          </div>
        </Card>
      )}

      {/* Error Message */}
      {error && (
        <Card className="p-4 bg-red-50 dark:bg-red-950 border-red-200 dark:border-red-800">
          <div className="flex items-center gap-3 text-red-600 dark:text-red-400">
            <AlertCircle className="w-5 h-5" />
            <p>{error}</p>
          </div>
        </Card>
      )}

      {/* Course Info */}
      <Card className="p-6">
        <h2 className="text-xl font-semibold text-foreground mb-2">{course.name}</h2>
        <div className="text-foreground-muted space-y-1">
          {course.city && <p>City: {course.city}</p>}
          {course.state && <p>State: {course.state}</p>}
          <p>Country: {course.country}</p>
          {course.address && <p>Address: {course.address}</p>}
        </div>
      </Card>

      {/* Map */}
      <Card className="p-6">
        <div className="mb-4">
          <h3 className="text-lg font-semibold text-foreground mb-2">Location</h3>
          <p className="text-sm text-foreground-muted mb-4">
            {latitude && longitude
              ? "Coordinates set. You can adjust by clicking on the map."
              : "Click on the map to set the course location, or use geocoding if you have an address."}
          </p>
          {latitude && longitude && (
            <div className="mb-4 p-3 bg-background-secondary rounded-lg">
              <p className="text-sm">
                <strong>Latitude:</strong> {latitude.toFixed(6)}
              </p>
              <p className="text-sm">
                <strong>Longitude:</strong> {longitude.toFixed(6)}
              </p>
            </div>
          )}
        </div>
        <MapComponent
          initialLat={latitude || undefined}
          initialLon={longitude || undefined}
          onMapClick={handleMapClick}
        />
      </Card>

      {/* Additional Information */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold text-foreground mb-4">Additional Information</h3>
        <div className="space-y-4">
          {/* Address for Geocoding */}
          <div>
            <Label htmlFor="address">Address (for geocoding)</Label>
            <div className="flex gap-2 mt-1">
              <Input
                id="address"
                value={address || course.address || ""}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Enter full address"
              />
              <Button
                onClick={handleGeocode}
                disabled={geocoding || !address}
                variant="outline"
              >
                {geocoding ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <>
                    <Navigation className="w-4 h-4 mr-2" />
                    Geocode
                  </>
                )}
              </Button>
            </div>
          </div>

          {/* Phone */}
          {course.missing_fields?.includes("phone") && (
            <div>
              <Label htmlFor="phone">Phone Number</Label>
              <Input
                id="phone"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="Enter phone number"
                className="mt-1"
              />
            </div>
          )}

          {/* Website */}
          {course.missing_fields?.includes("website") && (
            <div>
              <Label htmlFor="website">Website</Label>
              <Input
                id="website"
                value={website}
                onChange={(e) => setWebsite(e.target.value)}
                placeholder="https://example.com"
                className="mt-1"
              />
            </div>
          )}
        </div>
      </Card>

      {/* Submit */}
      <div className="flex gap-4">
        <Button
          onClick={handleSubmit}
          disabled={submitting || !latitude || !longitude}
          className="flex-1"
        >
          {submitting ? (
            <>
              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
              Submitting...
            </>
          ) : (
            <>
              <CheckCircle className="w-4 h-4 mr-2" />
              Complete Course
            </>
          )}
        </Button>
        <Button
          variant="outline"
          onClick={() => router.push("/courses/incomplete")}
          disabled={submitting}
        >
          Cancel
        </Button>
      </div>
    </div>
  );
}
