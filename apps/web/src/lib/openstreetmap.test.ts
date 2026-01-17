import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  searchOSMCourses,
  searchOSMCoursesByName,
  convertOSMCourseToContribution,
  type OSMCourseData,
} from './openstreetmap';

// Mock fetch globally
global.fetch = vi.fn();

describe('openstreetmap', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('searchOSMCourses', () => {
    it('should search for courses near a location', async () => {
      const mockResponse = {
        elements: [
          {
            id: 123,
            type: 'way',
            lat: 36.5725,
            lon: -121.9486,
            center: { lat: 36.5725, lon: -121.9486 },
            tags: {
              name: 'Pebble Beach Golf Links',
              'addr:city': 'Pebble Beach',
              'addr:state': 'CA',
              leisure: 'golf_course',
            },
          },
        ],
      };

      (global.fetch as any).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await searchOSMCourses(36.5725, -121.9486, 5000);
      expect(result.courses).toHaveLength(1);
      expect(result.courses[0].name).toBe('Pebble Beach Golf Links');
      expect(result.courses[0].lat).toBe(36.5725);
      expect(result.courses[0].lon).toBe(-121.9486);
    });

    it('should return empty array when no courses found', async () => {
      (global.fetch as any).mockResolvedValueOnce({
        ok: true,
        json: async () => ({ elements: [] }),
      });

      const result = await searchOSMCourses(36.5725, -121.9486, 5000);
      expect(result.courses).toHaveLength(0);
    });

    it('should handle API errors gracefully', async () => {
      (global.fetch as any).mockRejectedValueOnce(new Error('API Error'));

      const result = await searchOSMCourses(36.5725, -121.9486, 5000);
      expect(result.courses).toHaveLength(0);
    });

    it('should handle HTTP errors', async () => {
      (global.fetch as any).mockResolvedValueOnce({
        ok: false,
        statusText: 'Not Found',
      });

      const result = await searchOSMCourses(36.5725, -121.9486, 5000);
      expect(result.courses).toHaveLength(0);
    });
  });

  describe('searchOSMCoursesByName', () => {
    it('should search for courses by name', async () => {
      const mockResponse = {
        elements: [
          {
            id: 123,
            type: 'way',
            lat: 36.5725,
            lon: -121.9486,
            center: { lat: 36.5725, lon: -121.9486 },
            tags: {
              name: 'Pebble Beach Golf Links',
              leisure: 'golf_course',
            },
          },
        ],
      };

      (global.fetch as any).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await searchOSMCoursesByName('Pebble Beach', 10);
      expect(result.courses).toHaveLength(1);
      expect(result.courses[0].name).toBe('Pebble Beach Golf Links');
    });

    it('should limit results', async () => {
      const mockResponse = {
        elements: Array.from({ length: 20 }, (_, i) => ({
          id: i,
          type: 'way',
          lat: 36.5725,
          lon: -121.9486,
          center: { lat: 36.5725, lon: -121.9486 },
          tags: {
            name: `Course ${i}`,
            leisure: 'golf_course',
          },
        })),
      };

      (global.fetch as any).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await searchOSMCoursesByName('Course', 10);
      expect(result.courses).toHaveLength(10);
    });
  });

  describe('convertOSMCourseToContribution', () => {
    it('should convert OSM course data to contribution format', () => {
      const osmCourse: OSMCourseData = {
        id: 123,
        name: 'Pebble Beach Golf Links',
        lat: 36.5725,
        lon: -121.9486,
        type: 'way',
        tags: {
          name: 'Pebble Beach Golf Links',
          'addr:city': 'Pebble Beach',
          'addr:state': 'CA',
          'addr:country': 'USA',
          'addr:street': '17-Mile Drive',
          'addr:housenumber': '1700',
          phone: '(831) 624-3811',
          website: 'https://www.pebblebeach.com',
        },
        geometry: [
          { lat: 36.5725, lon: -121.9486 },
          { lat: 36.5730, lon: -121.9490 },
        ],
      };

      const result = convertOSMCourseToContribution(osmCourse);
      expect(result.name).toBe('Pebble Beach Golf Links');
      expect(result.city).toBe('Pebble Beach');
      expect(result.state).toBe('CA');
      expect(result.country).toBe('USA');
      expect(result.latitude).toBe(36.5725);
      expect(result.longitude).toBe(-121.9486);
      expect(result.phone).toBe('(831) 624-3811');
      expect(result.website).toBe('https://www.pebblebeach.com');
      expect(result.address).toContain('1700');
      expect(result.address).toContain('17-Mile Drive');
      expect(result.geojson_data).toBeDefined();
      expect(result.source).toBe('osm');
    });

    it('should handle missing optional fields', () => {
      const osmCourse: OSMCourseData = {
        id: 123,
        name: 'Unnamed Golf Course',
        lat: 36.5725,
        lon: -121.9486,
        type: 'node',
        tags: {},
      };

      const result = convertOSMCourseToContribution(osmCourse);
      expect(result.name).toBe('Unnamed Golf Course');
      expect(result.city).toBeNull();
      expect(result.state).toBeNull();
      expect(result.country).toBe('USA'); // Default
      expect(result.phone).toBeNull();
      expect(result.website).toBeNull();
    });
  });
});
