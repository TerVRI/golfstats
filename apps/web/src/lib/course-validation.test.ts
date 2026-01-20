import { describe, it, expect } from 'vitest';
import { validateCourseData, detectDuplicates, type CourseData } from './course-validation';

describe('course-validation', () => {
  describe('validateCourseData', () => {
    it('should validate a complete course data', () => {
      // Create a minimal valid course (no hole data to avoid par validation issues)
      const courseData: CourseData = {
        name: 'Pebble Beach Golf Links',
        par: 72,
        holes: 18,
        course_rating: 75.5,
        slope_rating: 145,
        latitude: 36.5725,
        longitude: -121.9486,
        // No hole_data - this is valid (optional field)
      };

      const result = validateCourseData(courseData);
      // Should be valid - all required fields present
      expect(result.isValid).toBe(true);
      expect(result.errors.length).toBe(0);
    });

    it('should validate course with matching par totals', () => {
      // Create 18 holes with pars that sum to 72
      const holePars = [4, 5, 4, 4, 3, 4, 4, 3, 5, 4, 4, 4, 3, 5, 4, 4, 3, 5]; // Sum = 72 (changed last 4 to 5)
      const courseData: CourseData = {
        name: 'Test Course',
        par: 72,
        holes: 18,
        latitude: 36.5725,
        longitude: -121.9486,
        hole_data: holePars.map((par, i) => ({
          hole_number: i + 1,
          par: par,
          yardages: { blue: par === 3 ? 180 : par === 4 ? 380 : 520 }, // Realistic yardages
          tee_locations: [{ lat: 36.5730 + (i * 0.0001), lon: -121.9490 + (i * 0.0001) }], // Different locations
          green_center: { lat: 36.5735 + (i * 0.0001), lon: -121.9495 + (i * 0.0001) }, // Different from tee
        })),
      };

      const result = validateCourseData(courseData);
      // Should be valid - pars match, no errors
      expect(result.errors.length).toBe(0);
      expect(result.isValid).toBe(true);
    });

    it('should error when name is missing', () => {
      const courseData: CourseData = {
        latitude: 36.5725,
        longitude: -121.9486,
      };

      const result = validateCourseData(courseData);
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('Course name is required');
    });

    it('should error when GPS coordinates are missing', () => {
      const courseData: CourseData = {
        name: 'Test Course',
      };

      const result = validateCourseData(courseData);
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('GPS coordinates (latitude and longitude) are required');
    });

    it('should error when latitude is out of range', () => {
      const courseData: CourseData = {
        name: 'Test Course',
        latitude: 100, // Invalid
        longitude: -121.9486,
      };

      const result = validateCourseData(courseData);
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('Latitude must be between -90 and 90');
    });

    it('should error when longitude is out of range', () => {
      const courseData: CourseData = {
        name: 'Test Course',
        latitude: 36.5725,
        longitude: 200, // Invalid
      };

      const result = validateCourseData(courseData);
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('Longitude must be between -180 and 180');
    });

    it('should error when par totals do not match', () => {
      const courseData: CourseData = {
        name: 'Test Course',
        par: 72,
        latitude: 36.5725,
        longitude: -121.9486,
        hole_data: [
          { hole_number: 1, par: 4 },
          { hole_number: 2, par: 4 },
        ], // Total par = 8, but course par = 72
      };

      const result = validateCourseData(courseData);
      expect(result.isValid).toBe(false);
      expect(result.errors.some((e) => e.includes("doesn't match course par"))).toBe(true);
    });

    it('should warn about unusual par values', () => {
      const courseData: CourseData = {
        name: 'Test Course',
        par: 200, // Unusual
        latitude: 36.5725,
        longitude: -121.9486,
      };

      const result = validateCourseData(courseData);
      expect(result.warnings.some((w) => w.includes('unusual'))).toBe(true);
    });

    it('should warn about unusual yardages for par 3', () => {
      const courseData: CourseData = {
        name: 'Test Course',
        latitude: 36.5725,
        longitude: -121.9486,
        hole_data: [
          {
            hole_number: 1,
            par: 3,
            yardages: { blue: 400 }, // Too long for par 3
          },
        ],
      };

      const result = validateCourseData(courseData);
      expect(result.warnings.some((w) => w.includes('Par 3 with') && w.includes('seems long'))).toBe(true);
    });

    it('should warn when tee and green are very close', () => {
      const courseData: CourseData = {
        name: 'Test Course',
        latitude: 36.5725,
        longitude: -121.9486,
        hole_data: [
          {
            hole_number: 1,
            par: 4,
            tee_locations: [{ lat: 36.5730, lon: -121.9490 }],
            green_center: { lat: 36.5731, lon: -121.9491 }, // Very close
          },
        ],
      };

      const result = validateCourseData(courseData);
      expect(result.warnings.some((w) => w.includes('very close'))).toBe(true);
    });
  });

  describe('detectDuplicates', () => {
    it('should detect duplicates with similar names and close locations', () => {
      const course1: CourseData = {
        name: 'Pebble Beach Golf Links',
        latitude: 36.5725,
        longitude: -121.9486,
        par: 72,
      };

      const course2: CourseData = {
        name: 'Pebble Beach Golf Course', // Similar name
        latitude: 36.5726, // Very close (within 100m)
        longitude: -121.9487,
        par: 72,
      };

      const result = detectDuplicates(course1, course2);
      expect(result.isDuplicate).toBe(true);
      expect(result.similarityScore).toBeGreaterThan(70);
      expect(result.reasons.length).toBeGreaterThan(0);
    });

    it('should not detect duplicates when names are different', () => {
      const course1: CourseData = {
        name: 'Pebble Beach Golf Links',
        latitude: 36.5725,
        longitude: -121.9486,
      };

      const course2: CourseData = {
        name: 'Augusta National',
        latitude: 36.5725, // Same location
        longitude: -121.9486,
      };

      const result = detectDuplicates(course1, course2);
      expect(result.isDuplicate).toBe(false);
      expect(result.similarityScore).toBeLessThan(70);
    });

    it('should not detect duplicates when locations are far apart', () => {
      const course1: CourseData = {
        name: 'Pebble Beach Golf Links',
        latitude: 36.5725,
        longitude: -121.9486,
      };

      const course2: CourseData = {
        name: 'Pebble Beach Golf Links', // Same name
        latitude: 40.7128, // Far away (New York)
        longitude: -74.0060,
      };

      const result = detectDuplicates(course1, course2);
      expect(result.isDuplicate).toBe(false);
    });

    it('should give higher similarity for exact name match', () => {
      const course1: CourseData = {
        name: 'Pebble Beach Golf Links',
        latitude: 36.5725,
        longitude: -121.9486,
        par: 72,
      };

      const course2: CourseData = {
        name: 'Pebble Beach Golf Links', // Exact match
        latitude: 36.5726, // Very close
        longitude: -121.9487,
        par: 72,
      };

      const result = detectDuplicates(course1, course2);
      expect(result.similarityScore).toBeGreaterThan(80);
    });
  });
});
