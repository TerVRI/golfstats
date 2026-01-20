/**
 * Utility functions for incomplete courses
 */

import { createClient } from "@/lib/supabase/client";

export interface IncompleteCourse {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string;
  address: string | null;
  phone: string | null;
  website: string | null;
  latitude: number | null;
  longitude: number | null;
  status: "incomplete" | "needs_location" | "needs_verification";
  completion_priority: number;
  missing_fields: string[];
  geocoded: boolean;
  osm_id: string | null;
  osm_type: string | null;
  created_at: string;
}

export interface CompletionData {
  latitude: number;
  longitude: number;
  geocoded?: boolean;
  phone?: string;
  website?: string;
  address?: string;
  city?: string;
  state?: string;
}

/**
 * Fetch incomplete courses
 */
export async function fetchIncompleteCourses(options?: {
  country?: string;
  minPriority?: number;
  missingField?: string;
  limit?: number;
  offset?: number;
}): Promise<IncompleteCourse[]> {
  const supabase = createClient();
  
  let query = supabase
    .from("course_contributions")
    .select("*")
    .in("status", ["incomplete", "needs_location", "needs_verification"])
    .order("completion_priority", { ascending: false })
    .order("created_at", { ascending: false });

  if (options?.country) {
    query = query.eq("country", options.country);
  }

  if (options?.minPriority) {
    query = query.gte("completion_priority", options.minPriority);
  }

  if (options?.missingField) {
    query = query.contains("missing_fields", [options.missingField]);
  }

  if (options?.limit) {
    query = query.limit(options.limit);
  }

  if (options?.offset) {
    query = query.range(options.offset, options.offset + (options.limit || 50) - 1);
  }

  const { data, error } = await query;

  if (error) {
    console.error("Error fetching incomplete courses:", error);
    throw error;
  }

  return (data || []) as IncompleteCourse[];
}

/**
 * Complete an incomplete course
 */
export async function completeIncompleteCourse(
  courseId: string,
  completionData: CompletionData
): Promise<void> {
  const supabase = createClient();
  
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    throw new Error("You must be logged in to complete a course");
  }

  // Update the course
  const updateData: any = {
    latitude: completionData.latitude,
    longitude: completionData.longitude,
    status: "needs_verification", // Changed to needs_verification for review
    completed_by: user.id,
    completed_at: new Date().toISOString(),
  };

  if (completionData.geocoded !== undefined) {
    updateData.geocoded = completionData.geocoded;
    if (completionData.geocoded) {
      updateData.geocoded_at = new Date().toISOString();
    }
  }

  // Update optional fields if provided
  if (completionData.phone) updateData.phone = completionData.phone;
  if (completionData.website) updateData.website = completionData.website;
  if (completionData.address) updateData.address = completionData.address;
  if (completionData.city) updateData.city = completionData.city;
  if (completionData.state) updateData.state = completionData.state;

  // Remove completed fields from missing_fields
  const { data: course } = await supabase
    .from("course_contributions")
    .select("missing_fields")
    .eq("id", courseId)
    .single();

  if (course) {
    const newMissingFields = (course.missing_fields || []).filter(
      (field: string) => 
        !(completionData.latitude && field === "latitude") &&
        !(completionData.longitude && field === "longitude") &&
        !(completionData.phone && field === "phone") &&
        !(completionData.website && field === "website") &&
        !(completionData.address && field === "address")
    );
    updateData.missing_fields = newMissingFields;
  }

  const { error } = await supabase
    .from("course_contributions")
    .update(updateData)
    .eq("id", courseId);

  if (error) {
    console.error("Error completing course:", error);
    throw error;
  }
}

/**
 * Geocode an address using a geocoding service
 * Note: This is a placeholder - you'll need to integrate with a real geocoding API
 */
export async function geocodeAddress(address: string, city?: string, country?: string): Promise<{ lat: number; lon: number } | null> {
  // Build full address
  const fullAddress = [address, city, country].filter(Boolean).join(", ");
  
  // For now, return null - you'll need to integrate with Google Geocoding API,
  // OpenStreetMap Nominatim, or another service
  // Example with Nominatim (free, but has rate limits):
  try {
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(fullAddress)}&limit=1`,
      {
        headers: {
          'User-Agent': 'RoundCaddy/1.0' // Required by Nominatim
        }
      }
    );
    
    if (!response.ok) return null;
    
    const data = await response.json();
    if (data && data.length > 0) {
      return {
        lat: parseFloat(data[0].lat),
        lon: parseFloat(data[0].lon),
      };
    }
  } catch (error) {
    console.error("Geocoding error:", error);
  }
  
  return null;
}

/**
 * Get user's completion statistics
 */
export async function getUserCompletions(userId: string): Promise<{
  total: number;
  verified: number;
  pending: number;
}> {
  const supabase = createClient();
  
  const { data, error } = await supabase
    .from("course_contributions")
    .select("status")
    .eq("completed_by", userId);

  if (error) {
    console.error("Error fetching user completions:", error);
    throw error;
  }

  const courses = data || [];
  return {
    total: courses.length,
    verified: courses.filter((c: any) => c.status === "approved").length,
    pending: courses.filter((c: any) => c.status === "needs_verification" || c.status === "pending").length,
  };
}
