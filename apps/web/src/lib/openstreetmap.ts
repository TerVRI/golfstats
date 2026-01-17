/**
 * OpenStreetMap Integration
 * Fetches golf course data from OpenStreetMap using Overpass API
 */

export interface OSMCourseData {
  id: number;
  name: string;
  lat: number;
  lon: number;
  tags: {
    name?: string;
    "addr:city"?: string;
    "addr:state"?: string;
    "addr:country"?: string;
    "addr:postcode"?: string;
    "addr:street"?: string;
    "addr:housenumber"?: string;
    phone?: string;
    website?: string;
    "contact:website"?: string;
    "contact:phone"?: string;
    [key: string]: string | undefined;
  };
  type: "way" | "node" | "relation";
  geometry?: Array<{ lat: number; lon: number }>;
}

export interface OSMSearchResult {
  courses: OSMCourseData[];
  bounds?: {
    minlat: number;
    minlon: number;
    maxlat: number;
    maxlon: number;
  };
}

/**
 * Search for golf courses in OpenStreetMap by location
 * @param lat Latitude
 * @param lon Longitude
 * @param radius Radius in meters (default: 5000 = 5km)
 * @returns Array of golf courses found
 */
export async function searchOSMCourses(
  lat: number,
  lon: number,
  radius: number = 5000
): Promise<OSMSearchResult> {
  try {
    // Overpass API query to find golf courses near a location
    const query = `
      [out:json][timeout:25];
      (
        way["leisure"="golf_course"](around:${radius},${lat},${lon});
        relation["leisure"="golf_course"](around:${radius},${lat},${lon});
        node["leisure"="golf_course"](around:${radius},${lat},${lon});
      );
      out center meta;
    `;

    const response = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: `data=${encodeURIComponent(query)}`,
    });

    if (!response.ok) {
      throw new Error(`OSM API error: ${response.statusText}`);
    }

    const data = await response.json();

    const courses: OSMCourseData[] = (data.elements || []).map((element: any) => {
      const course: OSMCourseData = {
        id: element.id,
        name: element.tags?.name || "Unnamed Golf Course",
        lat: element.lat || element.center?.lat || 0,
        lon: element.lon || element.center?.lon || 0,
        tags: element.tags || {},
        type: element.type,
      };

      // Extract geometry for ways/relations
      if (element.geometry) {
        course.geometry = element.geometry.map((point: any) => ({
          lat: point.lat,
          lon: point.lon,
        }));
      }

      return course;
    });

    return {
      courses,
      bounds: data.bounds,
    };
  } catch (error) {
    console.error("Error fetching OSM courses:", error);
    return { courses: [] };
  }
}

/**
 * Search for golf courses by name
 * @param query Search query (course name)
 * @param limit Maximum number of results (default: 10)
 * @returns Array of golf courses found
 */
export async function searchOSMCoursesByName(
  query: string,
  limit: number = 10
): Promise<OSMSearchResult> {
  try {
    // Overpass API query to search by name
    const overpassQuery = `
      [out:json][timeout:25];
      (
        way["leisure"="golf_course"]["name"~"${query}",i];
        relation["leisure"="golf_course"]["name"~"${query}",i];
        node["leisure"="golf_course"]["name"~"${query}",i];
      );
      out center meta;
      (._;>;);
      out skel;
    `;

    const response = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: `data=${encodeURIComponent(overpassQuery)}`,
    });

    if (!response.ok) {
      throw new Error(`OSM API error: ${response.statusText}`);
    }

    const data = await response.json();

    const courses: OSMCourseData[] = (data.elements || [])
      .slice(0, limit)
      .map((element: any) => {
        const course: OSMCourseData = {
          id: element.id,
          name: element.tags?.name || "Unnamed Golf Course",
          lat: element.lat || element.center?.lat || 0,
          lon: element.lon || element.center?.lon || 0,
          tags: element.tags || {},
          type: element.type,
        };

        if (element.geometry) {
          course.geometry = element.geometry.map((point: any) => ({
            lat: point.lat,
            lon: point.lon,
          }));
        }

        return course;
      });

    return { courses };
  } catch (error) {
    console.error("Error searching OSM courses:", error);
    return { courses: [] };
  }
}

/**
 * Convert OSM course data to our course contribution format
 * @param osmCourse OSM course data
 * @returns Course data in our format
 */
export function convertOSMCourseToContribution(osmCourse: OSMCourseData) {
  const tags = osmCourse.tags;

  return {
    name: tags.name || "Unnamed Golf Course",
    city: tags["addr:city"] || null,
    state: tags["addr:state"] || null,
    country: tags["addr:country"] || "USA",
    address: [
      tags["addr:housenumber"],
      tags["addr:street"],
      tags["addr:city"],
      tags["addr:state"],
      tags["addr:postcode"],
    ]
      .filter(Boolean)
      .join(", "),
    phone: tags.phone || tags["contact:phone"] || null,
    website: tags.website || tags["contact:website"] || null,
    latitude: osmCourse.lat,
    longitude: osmCourse.lon,
    geojson_data: osmCourse.geometry
      ? {
          type: "Polygon",
          coordinates: [osmCourse.geometry.map((p) => [p.lon, p.lat])],
        }
      : null,
    source: "osm" as const,
  };
}
