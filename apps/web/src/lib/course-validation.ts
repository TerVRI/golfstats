/**
 * Course Data Validation Utilities
 * Validates course data for quality and consistency
 */

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

export interface CourseData {
  name?: string;
  par?: number;
  holes?: number;
  course_rating?: number;
  slope_rating?: number;
  hole_data?: Array<{
    hole_number: number;
    par: number;
    yardages?: Record<string, number>;
    tee_locations?: Array<{ lat: number; lon: number }>;
    green_center?: { lat: number; lon: number };
  }>;
  latitude?: number;
  longitude?: number;
}

/**
 * Validate course data for quality and consistency
 */
export function validateCourseData(data: CourseData): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  // Required fields
  if (!data.name || data.name.trim().length === 0) {
    errors.push("Course name is required");
  }

  if (!data.latitude || !data.longitude) {
    errors.push("GPS coordinates (latitude and longitude) are required");
  } else {
    // Validate coordinate ranges
    if (data.latitude < -90 || data.latitude > 90) {
      errors.push("Latitude must be between -90 and 90");
    }
    if (data.longitude < -180 || data.longitude > 180) {
      errors.push("Longitude must be between -180 and 180");
    }
  }

  // Validate par
  if (data.par) {
    if (data.par < 54 || data.par > 144) {
      warnings.push("Course par seems unusual (typically 54-144)");
    }
  }

  // Validate ratings
  if (data.course_rating) {
    if (data.course_rating < 60 || data.course_rating > 80) {
      warnings.push("Course rating seems unusual (typically 60-80)");
    }
  }

  if (data.slope_rating) {
    if (data.slope_rating < 55 || data.slope_rating > 155) {
      warnings.push("Slope rating seems unusual (typically 55-155)");
    }
  }

  // Validate hole data
  if (data.hole_data && data.hole_data.length > 0) {
    const holes = data.hole_data.length;
    const expectedHoles = data.holes || 18;

    if (holes !== expectedHoles) {
      warnings.push(`Hole data count (${holes}) doesn't match expected holes (${expectedHoles})`);
    }

    // Validate par totals
    if (data.par) {
      const totalPar = data.hole_data.reduce((sum, hole) => sum + (hole.par || 0), 0);
      if (totalPar !== data.par) {
        errors.push(`Total hole pars (${totalPar}) doesn't match course par (${data.par})`);
      }
    }

    // Validate each hole
    data.hole_data.forEach((hole, index) => {
      // Validate par
      if (hole.par < 3 || hole.par > 6) {
        warnings.push(`Hole ${hole.hole_number || index + 1}: Par seems unusual (${hole.par})`);
      }

      // Validate yardages
      if (hole.yardages) {
        Object.entries(hole.yardages).forEach(([tee, yards]) => {
          if (yards < 50 || yards > 800) {
            warnings.push(
              `Hole ${hole.hole_number || index + 1} ${tee} tee: Yardage seems unusual (${yards} yards)`
            );
          }

          // Check if yardage matches par
          if (hole.par === 3 && yards > 250) {
            warnings.push(`Hole ${hole.hole_number || index + 1}: Par 3 with ${yards} yards seems long`);
          }
          if (hole.par === 4 && (yards < 200 || yards > 500)) {
            warnings.push(`Hole ${hole.hole_number || index + 1}: Par 4 with ${yards} yards seems unusual`);
          }
          if (hole.par === 5 && yards < 400) {
            warnings.push(`Hole ${hole.hole_number || index + 1}: Par 5 with ${yards} yards seems short`);
          }
        });
      }

      // Validate GPS coordinates
      if (hole.tee_locations && hole.tee_locations.length > 0) {
        hole.tee_locations.forEach((tee, teeIndex) => {
          if (!tee.lat || !tee.lon) {
            warnings.push(`Hole ${hole.hole_number || index + 1} tee ${teeIndex + 1}: Missing GPS coordinates`);
          } else {
            if (tee.lat < -90 || tee.lat > 90 || tee.lon < -180 || tee.lon > 180) {
              errors.push(`Hole ${hole.hole_number || index + 1} tee ${teeIndex + 1}: Invalid GPS coordinates`);
            }
          }
        });
      }

      if (hole.green_center) {
        if (!hole.green_center.lat || !hole.green_center.lon) {
          warnings.push(`Hole ${hole.hole_number || index + 1}: Green center missing GPS coordinates`);
        } else {
          // Check distance from course center (should be reasonable)
          if (data.latitude && data.longitude) {
            const distance = calculateDistance(
              data.latitude,
              data.longitude,
              hole.green_center.lat,
              hole.green_center.lon
            );
            if (distance > 5000) {
              // More than 5km from course center
              warnings.push(
                `Hole ${hole.hole_number || index + 1}: Green is ${distance.toFixed(0)}m from course center (seems far)`
              );
            }
          }
        }
      }

      // Check if tee and green are too close or too far
      if (hole.tee_locations && hole.tee_locations.length > 0 && hole.green_center) {
        hole.tee_locations.forEach((tee) => {
          if (tee.lat && tee.lon) {
            const distance = calculateDistance(tee.lat, tee.lon, hole.green_center!.lat, hole.green_center!.lon);
            if (distance < 50) {
              warnings.push(`Hole ${hole.hole_number || index + 1}: Tee and green are very close (${distance.toFixed(0)}m)`);
            }
            if (distance > 1000) {
              warnings.push(`Hole ${hole.hole_number || index + 1}: Tee and green are very far (${distance.toFixed(0)}m)`);
            }
          }
        });
      }
    });
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
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

/**
 * Detect potential duplicate courses
 */
export function detectDuplicates(
  course1: CourseData,
  course2: CourseData
): { isDuplicate: boolean; similarityScore: number; reasons: string[] } {
  let similarityScore = 0;
  const reasons: string[] = [];

  // Name similarity (0-40 points)
  if (course1.name && course2.name) {
    const nameSimilarity = calculateStringSimilarity(
      course1.name.toLowerCase(),
      course2.name.toLowerCase()
    );
    similarityScore += nameSimilarity * 40;
    if (nameSimilarity > 0.8) {
      reasons.push("Very similar names");
    }
  }

  // Location proximity (0-40 points)
  if (course1.latitude && course1.longitude && course2.latitude && course2.longitude) {
    const distance = calculateDistance(
      course1.latitude,
      course1.longitude,
      course2.latitude,
      course2.longitude
    );
    if (distance < 100) {
      // Within 100 meters
      similarityScore += 40;
      reasons.push("Very close location (< 100m)");
    } else if (distance < 500) {
      similarityScore += 30;
      reasons.push("Close location (< 500m)");
    } else if (distance < 1000) {
      similarityScore += 20;
      reasons.push("Nearby location (< 1km)");
    }
  }

  // Par similarity (0-10 points)
  if (course1.par && course2.par && course1.par === course2.par) {
    similarityScore += 10;
    reasons.push("Same par");
  }

  // Rating similarity (0-10 points)
  if (
    course1.course_rating &&
    course2.course_rating &&
    Math.abs(course1.course_rating - course2.course_rating) < 1
  ) {
    similarityScore += 5;
    reasons.push("Similar course rating");
  }

  return {
    isDuplicate: similarityScore >= 70,
    similarityScore: Math.min(100, similarityScore),
    reasons,
  };
}

/**
 * Calculate string similarity using Levenshtein distance
 */
function calculateStringSimilarity(str1: string, str2: string): number {
  const longer = str1.length > str2.length ? str1 : str2;
  const shorter = str1.length > str2.length ? str2 : str1;
  if (longer.length === 0) {
    return 1.0;
  }
  return (longer.length - levenshteinDistance(longer, shorter)) / longer.length;
}

function levenshteinDistance(str1: string, str2: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1
        );
      }
    }
  }

  return matrix[str2.length][str1.length];
}
