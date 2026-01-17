/**
 * Smart Suggestions for Course Contributions
 * Provides personalized recommendations for users
 */

import { createClient } from "@/lib/supabase/client";

export interface CourseSuggestion {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  latitude: number | null;
  longitude: number | null;
  completeness_score: number;
  missing_critical_fields: string[];
  distance_km?: number;
  reason: string;
}

/**
 * Get courses near user that need data
 */
export async function getCoursesNearYouNeedingData(
  userLat: number,
  userLon: number,
  radiusKm: number = 50
): Promise<CourseSuggestion[]> {
  const supabase = createClient();

  try {
    // Get courses within radius that have low completeness
    const { data: courses, error } = await supabase
      .from("courses")
      .select("id, name, city, state, latitude, longitude, completeness_score, missing_critical_fields")
      .not("latitude", "is", null)
      .not("longitude", "is", null)
      .lt("completeness_score", 70)
      .limit(20);

    if (error) throw error;

    // Calculate distances and filter
    const suggestions: CourseSuggestion[] = (courses || [])
      .map((course) => {
        if (!course.latitude || !course.longitude) return null;

        const distance = calculateDistance(
          userLat,
          userLon,
          course.latitude,
          course.longitude
        );

        if (distance > radiusKm * 1000) return null; // Convert km to meters

        return {
          ...course,
          distance_km: distance / 1000,
          reason: `Only ${course.completeness_score}% complete, ${distance.toFixed(1)}km away`,
        };
      })
      .filter((s): s is CourseSuggestion => s !== null)
      .sort((a, b) => (a.distance_km || 0) - (b.distance_km || 0))
      .slice(0, 10);

    return suggestions;
  } catch (error) {
    console.error("Error getting courses near you:", error);
    return [];
  }
}

/**
 * Get courses similar to ones user has contributed
 */
export async function getSimilarCoursesToContributed(
  userId: string
): Promise<CourseSuggestion[]> {
  const supabase = createClient();

  try {
    // Get courses user has contributed
    const { data: contributions } = await supabase
      .from("course_contributions")
      .select("city, state, latitude, longitude")
      .eq("contributor_id", userId)
      .not("latitude", "is", null)
      .not("longitude", "is", null)
      .limit(5);

    if (!contributions || contributions.length === 0) return [];

    // Get average location
    const avgLat =
      contributions.reduce((sum, c) => sum + (c.latitude || 0), 0) /
      contributions.length;
    const avgLon =
      contributions.reduce((sum, c) => sum + (c.longitude || 0), 0) /
      contributions.length;

    // Get courses in same area that need data
    return getCoursesNearYouNeedingData(avgLat, avgLon, 100);
  } catch (error) {
    console.error("Error getting similar courses:", error);
    return [];
  }
}

/**
 * Get courses that need verification (low confirmation count)
 */
export async function getCoursesNeedingVerification(
  limit: number = 10
): Promise<CourseSuggestion[]> {
  const supabase = createClient();

  try {
    const { data: courses, error } = await supabase
      .from("courses")
      .select(
        "id, name, city, state, latitude, longitude, confirmation_count, required_confirmations, completeness_score, missing_critical_fields"
      )
      .lt("confirmation_count", 2)
      .eq("is_verified", false)
      .order("confirmation_count", { ascending: true })
      .limit(limit);

    if (error) throw error;

    return (courses || []).map((course) => ({
      ...course,
      reason: `Needs ${course.required_confirmations - course.confirmation_count} more confirmation(s)`,
    }));
  } catch (error) {
    console.error("Error getting courses needing verification:", error);
    return [];
  }
}

/**
 * Calculate distance between two GPS coordinates (in meters)
 */
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}
