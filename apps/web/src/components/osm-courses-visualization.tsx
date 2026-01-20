"use client";

import { useEffect, useState, useRef } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap, CircleMarker } from "react-leaflet";
import { LatLngBounds, Icon } from "leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import "leaflet.markercluster/dist/MarkerCluster.css";
import "leaflet.markercluster/dist/MarkerCluster.Default.css";
import "leaflet.markercluster";
import { ClusterLayer, type OSMCourse } from "./osm-courses-visualization-cluster";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  MapPin,
  Globe,
  TrendingUp,
  Filter,
  Search,
  Zap,
  Layers,
  Eye,
  EyeOff,
  Maximize2,
  Minimize2,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

// Fix for default marker icons
if (typeof window !== "undefined") {
  delete (Icon.Default.prototype as any)._getIconUrl;
  Icon.Default.mergeOptions({
    iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
    iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  });
}

// Custom golf course icon
const createGolfIcon = (color: string = "#10b981") => {
  return new Icon({
    iconUrl: `data:image/svg+xml;base64,${btoa(`
      <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
        <circle cx="16" cy="16" r="14" fill="${color}" stroke="white" stroke-width="2" opacity="0.9"/>
        <circle cx="16" cy="16" r="8" fill="white" opacity="0.3"/>
        <text x="16" y="20" font-size="14" fill="white" text-anchor="middle" font-weight="bold">⛳</text>
      </svg>
    `)}`,
    iconSize: [32, 32],
    iconAnchor: [16, 32],
    popupAnchor: [0, -32],
  });
};


interface MapControllerProps {
  bounds?: LatLngBounds;
  center?: [number, number];
  zoom?: number;
}

function MapController({ bounds, center, zoom }: MapControllerProps) {
  const map = useMap();
  
  useEffect(() => {
    if (bounds) {
      map.fitBounds(bounds, { padding: [50, 50] });
    } else if (center && zoom) {
      map.setView(center, zoom);
    }
  }, [map, bounds, center, zoom]);
  
  return null;
}

export function OSMCoursesVisualization() {
  const [courses, setCourses] = useState<OSMCourse[]>([]);
  const [filteredCourses, setFilteredCourses] = useState<OSMCourse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCountry, setSelectedCountry] = useState<string>("all");
  const [showHeatmap, setShowHeatmap] = useState(false);
  const [showClusters, setShowClusters] = useState(true);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [stats, setStats] = useState({
    total: 0,
    byCountry: {} as Record<string, number>,
    byStatus: {} as Record<string, number>,
  });
  
  const mapRef = useRef<L.Map | null>(null);
  const markerClusterRef = useRef<L.MarkerClusterGroup | null>(null);

  // Load courses from database (viewport-based for performance)
  useEffect(() => {
    async function loadCourses() {
      try {
        setLoading(true);
        const supabase = createClient();
        
        // Get user's country for initial filter
        const { getUserCountry } = await import("@/lib/geolocation");
        const userLocation = await getUserCountry();
        
        let query = supabase
          .from("course_contributions")
          .select("id, name, latitude, longitude, country, city, state, source, status")
          .eq("source", "osm")
          .not("latitude", "is", null)
          .not("longitude", "is", null)
          .limit(1000); // Limit initial load

        // Filter by country by default if available
        if (userLocation && selectedCountry === "all") {
          query = query.eq("country", userLocation.country);
          setSelectedCountry(userLocation.country);
        }

        const { data, error } = await query;

        if (error) throw error;

        const coursesData = (data || []).map((c: any) => ({
          id: c.id,
          name: c.name,
          latitude: parseFloat(c.latitude),
          longitude: parseFloat(c.longitude),
          country: c.country || "Unknown",
          city: c.city,
          state: c.state,
          source: c.source,
          status: c.status,
        }));

        setCourses(coursesData);
        setFilteredCourses(coursesData);

        // Calculate stats
        const byCountry: Record<string, number> = {};
        const byStatus: Record<string, number> = {};
        
        coursesData.forEach((course) => {
          byCountry[course.country] = (byCountry[course.country] || 0) + 1;
          byStatus[course.status] = (byStatus[course.status] || 0) + 1;
        });

        setStats({
          total: coursesData.length,
          byCountry,
          byStatus,
        });
      } catch (err: any) {
        setError(err.message || "Failed to load courses");
        console.error("Error loading courses:", err);
      } finally {
        setLoading(false);
      }
    }

    loadCourses();
  }, []);

  // Filter courses
  useEffect(() => {
    let filtered = [...courses];

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (course) =>
          course.name.toLowerCase().includes(query) ||
          course.city?.toLowerCase().includes(query) ||
          course.country?.toLowerCase().includes(query)
      );
    }

    // Country filter
    if (selectedCountry !== "all") {
      filtered = filtered.filter((course) => course.country === selectedCountry);
    }

    setFilteredCourses(filtered);
  }, [searchQuery, selectedCountry, courses]);

  // Calculate bounds for filtered courses
  const getBounds = (): LatLngBounds | undefined => {
    if (filteredCourses.length === 0) return undefined;
    
    const lats = filteredCourses.map((c) => c.latitude);
    const lons = filteredCourses.map((c) => c.longitude);
    
    return new LatLngBounds(
      [Math.min(...lats), Math.min(...lons)],
      [Math.max(...lats), Math.max(...lons)]
    );
  };

  const countries = Object.keys(stats.byCountry).sort((a, b) => 
    (stats.byCountry[b] || 0) - (stats.byCountry[a] || 0)
  );

  if (loading) {
    return (
      <Card className="p-8 text-center">
        <div className="flex flex-col items-center gap-4">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-green-500"></div>
          <p className="text-foreground-muted">Loading golf courses from OpenStreetMap...</p>
        </div>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="p-8 text-center">
        <p className="text-red-500">{error}</p>
      </Card>
    );
  }

  return (
    <div className={cn("space-y-4", isFullscreen && "fixed inset-0 z-50 bg-background p-4")}>
      {/* Stats Dashboard */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border-green-500/30">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-foreground-muted">Total Courses</p>
              <p className="text-2xl font-bold text-foreground">{stats.total.toLocaleString()}</p>
            </div>
            <Globe className="w-8 h-8 text-green-500" />
          </div>
        </Card>

        <Card className="p-4 bg-gradient-to-br from-blue-500/20 to-cyan-500/20 border-blue-500/30">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-foreground-muted">Countries</p>
              <p className="text-2xl font-bold text-foreground">{countries.length}</p>
            </div>
            <MapPin className="w-8 h-8 text-blue-500" />
          </div>
        </Card>

        <Card className="p-4 bg-gradient-to-br from-purple-500/20 to-pink-500/20 border-purple-500/30">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-foreground-muted">Visible</p>
              <p className="text-2xl font-bold text-foreground">{filteredCourses.length.toLocaleString()}</p>
            </div>
            <Eye className="w-8 h-8 text-purple-500" />
          </div>
        </Card>

        <Card className="p-4 bg-gradient-to-br from-orange-500/20 to-red-500/20 border-orange-500/30">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-foreground-muted">Pending</p>
              <p className="text-2xl font-bold text-foreground">
                {(stats.byStatus["pending"] || 0).toLocaleString()}
              </p>
            </div>
            <TrendingUp className="w-8 h-8 text-orange-500" />
          </div>
        </Card>
      </div>

      {/* Controls */}
      <Card className="p-4">
        <div className="flex flex-wrap items-center gap-4">
          {/* Search */}
          <div className="flex-1 min-w-[200px]">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-foreground-muted" />
              <Input
                placeholder="Search courses..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
          </div>

          {/* Country Filter */}
          <div className="min-w-[150px]">
            <select
              value={selectedCountry}
              onChange={(e) => setSelectedCountry(e.target.value)}
              className="w-full px-3 py-2 bg-background-secondary border border-background-tertiary rounded-lg text-foreground"
            >
              <option value="all">All Countries</option>
              {countries.slice(0, 20).map((country) => (
                <option key={country} value={country}>
                  {country} ({stats.byCountry[country]})
                </option>
              ))}
            </select>
          </div>

          {/* Toggle Buttons */}
          <div className="flex gap-2">
            <Button
              size="sm"
              variant={showClusters ? "default" : "outline"}
              onClick={() => setShowClusters(!showClusters)}
            >
              <Layers className="w-4 h-4 mr-2" />
              Clusters
            </Button>
            <Button
              size="sm"
              variant={showHeatmap ? "default" : "outline"}
              onClick={() => setShowHeatmap(!showHeatmap)}
            >
              <Zap className="w-4 h-4 mr-2" />
              Heatmap
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setIsFullscreen(!isFullscreen)}
            >
              {isFullscreen ? (
                <>
                  <Minimize2 className="w-4 h-4 mr-2" />
                  Exit
                </>
              ) : (
                <>
                  <Maximize2 className="w-4 h-4 mr-2" />
                  Fullscreen
                </>
              )}
            </Button>
          </div>
        </div>
      </Card>

      {/* Map */}
      <Card className="overflow-hidden p-0">
        <div className={cn("w-full bg-background-secondary", isFullscreen ? "h-[calc(100vh-200px)]" : "h-[600px]")}>
          <MapContainer
            center={[20, 0]}
            zoom={2}
            style={{ height: "100%", width: "100%" }}
            whenCreated={(map) => {
              mapRef.current = map;
            }}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            <MapController bounds={getBounds()} />

            {/* Clustered Markers Layer */}
            {showClusters && (
              <ClusterLayer
                courses={filteredCourses}
                showClusters={showClusters}
                createGolfIcon={createGolfIcon}
              />
            )}

            {/* Non-clustered markers (when clustering is off) */}
            {!showClusters && filteredCourses.map((course) => (
              <Marker
                key={course.id}
                position={[course.latitude, course.longitude]}
                icon={createGolfIcon(
                  course.status === "approved" ? "#10b981" : 
                  course.status === "pending" ? "#f59e0b" : 
                  "#6b7280"
                )}
              >
                <Popup>
                  <div className="p-2 min-w-[200px]">
                    <h3 className="font-semibold text-foreground mb-1">{course.name}</h3>
                    {course.city && (
                      <p className="text-sm text-foreground-muted">
                        {[course.city, course.state, course.country].filter(Boolean).join(", ")}
                      </p>
                    )}
                    <div className="mt-2 flex items-center gap-2">
                      <span className={cn(
                        "px-2 py-1 rounded text-xs",
                        course.status === "approved" && "bg-green-500/20 text-green-500",
                        course.status === "pending" && "bg-yellow-500/20 text-yellow-500",
                        course.status === "rejected" && "bg-red-500/20 text-red-500"
                      )}>
                        {course.status}
                      </span>
                      <span className="text-xs text-foreground-muted">OSM</span>
                    </div>
                  </div>
                </Popup>
              </Marker>
            ))}

            {/* Heatmap overlay (simplified - would need leaflet.heat plugin for full implementation) */}
            {showHeatmap && filteredCourses.length > 0 && (
              <>
                {filteredCourses.slice(0, 1000).map((course) => (
                  <CircleMarker
                    key={`heat-${course.id}`}
                    center={[course.latitude, course.longitude]}
                    radius={15}
                    pathOptions={{
                      fillColor: "#ef4444",
                      fillOpacity: 0.3,
                      color: "#ef4444",
                      weight: 1,
                    }}
                  />
                ))}
              </>
            )}
          </MapContainer>
        </div>
      </Card>

      {/* Top Countries List */}
      {countries.length > 0 && (
        <Card className="p-4">
          <h3 className="font-semibold text-foreground mb-3">Top Countries</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-2">
            {countries.slice(0, 12).map((country) => {
              const count = stats.byCountry[country] || 0;
              const percentage = (count / stats.total) * 100;
              return (
                <button
                  key={country}
                  onClick={() => setSelectedCountry(country === selectedCountry ? "all" : country)}
                  className={cn(
                    "p-3 rounded-lg border text-left transition-all hover:scale-105",
                    selectedCountry === country
                      ? "bg-green-500/20 border-green-500"
                      : "bg-background-secondary border-background-tertiary"
                  )}
                >
                  <p className="font-medium text-foreground">{country}</p>
                  <p className="text-sm text-foreground-muted">{count.toLocaleString()}</p>
                  <div className="mt-2 h-1 bg-background-tertiary rounded-full overflow-hidden">
                    <div
                      className="h-full bg-green-500 transition-all"
                      style={{ width: `${percentage}%` }}
                    />
                  </div>
                </button>
              );
            })}
          </div>
        </Card>
      )}
    </div>
  );
}
