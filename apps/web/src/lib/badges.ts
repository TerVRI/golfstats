/**
 * Utility functions for badges system
 */

import { createClient } from "@/lib/supabase/client";

export interface Badge {
  id: string;
  user_id: string;
  badge_type: string;
  badge_name: string;
  badge_description: string | null;
  badge_icon: string | null;
  earned_at: string;
  progress: number;
  metadata: any;
}

export interface BadgeDefinition {
  badge_type: string;
  badge_name: string;
  badge_description: string;
  badge_icon: string;
  category: "completion" | "quality" | "contribution" | "verification";
  requirement_type: "count" | "threshold" | "custom";
  requirement_value: number | null;
  requirement_description: string | null;
  display_order: number;
}

export interface BadgeProgress {
  badge_type: string;
  badge_name: string;
  earned: boolean;
  progress: number;
}

/**
 * Fetch user's badges
 */
export async function fetchUserBadges(userId: string): Promise<Badge[]> {
  const supabase = createClient();
  
  const { data, error } = await supabase
    .from("user_badges")
    .select("*")
    .eq("user_id", userId)
    .order("earned_at", { ascending: false });

  if (error) {
    console.error("Error fetching user badges:", error);
    throw error;
  }

  return (data || []) as Badge[];
}

/**
 * Fetch badge definitions
 */
export async function fetchBadgeDefinitions(): Promise<BadgeDefinition[]> {
  const supabase = createClient();
  
  const { data, error } = await supabase
    .from("badge_definitions")
    .select("*")
    .order("display_order", { ascending: true });

  if (error) {
    console.error("Error fetching badge definitions:", error);
    throw error;
  }

  return (data || []) as BadgeDefinition[];
}

/**
 * Calculate badge progress for a user
 */
export async function calculateBadgeProgress(userId: string): Promise<BadgeProgress[]> {
  const supabase = createClient();
  
  const { data, error } = await supabase
    .rpc("calculate_user_badges", { p_user_id: userId });

  if (error) {
    console.error("Error calculating badge progress:", error);
    throw error;
  }

  return (data || []) as BadgeProgress[];
}

/**
 * Award a badge to a user (admin/system function)
 */
export async function awardBadge(
  userId: string,
  badgeType: string,
  progress: number = 100
): Promise<string> {
  const supabase = createClient();
  
  const { data, error } = await supabase
    .rpc("award_badge", {
      p_user_id: userId,
      p_badge_type: badgeType,
      p_progress: progress,
    });

  if (error) {
    console.error("Error awarding badge:", error);
    throw error;
  }

  return data as string;
}

/**
 * Get user's badge summary
 */
export async function getUserBadgeSummary(userId: string): Promise<{
  total: number;
  byCategory: Record<string, number>;
  recent: Badge[];
}> {
  const badges = await fetchUserBadges(userId);
  const definitions = await fetchBadgeDefinitions();
  
  const byCategory: Record<string, number> = {};
  badges.forEach((badge) => {
    const def = definitions.find((d) => d.badge_type === badge.badge_type);
    if (def) {
      byCategory[def.category] = (byCategory[def.category] || 0) + 1;
    }
  });

  return {
    total: badges.length,
    byCategory,
    recent: badges.slice(0, 5),
  };
}
