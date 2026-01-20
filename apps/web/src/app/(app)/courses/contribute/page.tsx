"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { CourseMapEditor } from "@/components/course-map-editor";
import { PolygonDrawingTool, PolygonData } from "@/components/polygon-drawing-tool";
import { PhotoUpload } from "@/components/photo-upload";
import { OSMAutofill } from "@/components/osm-autofill";
import { DataCompletenessIndicator } from "@/components/data-completeness-indicator";
import { validateCourseData } from "@/lib/course-validation";
import {
  MapPin,
  Loader2,
  CheckCircle2,
  AlertCircle,
  Info,
  Plus,
  Trash2,
  AlertTriangle,
  Layers,
} from "lucide-react";
import Link from "next/link";

interface HoleData {
  hole_number: number;
  par: number;
  yardages: Record<string, number>;
  handicap_index: number;
  tee_locations: Array<{ tee: string; lat: number; lon: number }>;
  green_center: { lat: number; lon: number };
  green_front: { lat: number; lon: number };
  green_back: { lat: number; lon: number };
  hazards: Array<{ type: string; lat?: number; lon?: number; polygon?: number[][] }>;
  // Polygon data
  fairway?: Array<[number, number]>;
  green?: Array<[number, number]>;
  rough?: Array<[number, number]>;
  bunkers?: Array<{ type: string; polygon: Array<[number, number]> }>;
  water_hazards?: Array<{ polygon: Array<[number, number]> }>;
  trees?: Array<{ polygon: Array<[number, number]> }>;
}

export default function ContributeCoursePage() {
  const router = useRouter();
  const supabase = createClient();
  const { user } = useUser();
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  const [formData, setFormData] = useState({
    name: "",
    city: "",
    state: "",
    country: "USA",
    address: "",
    phone: "",
    website: "",
    course_rating: "",
    slope_rating: "",
    par: "72",
    holes: "18",
    latitude: "",
    longitude: "",
  });

  const [holeData, setHoleData] = useState<HoleData[]>([]);
  const [photos, setPhotos] = useState<string[]>([]);
  const [currentHole, setCurrentHole] = useState<number>(1);
  const [mapMarkers, setMapMarkers] = useState<any[]>([]);
  const [polygons, setPolygons] = useState<PolygonData[]>([]);
  const [showPolygonTool, setShowPolygonTool] = useState(false);
  const [validationResult, setValidationResult] = useState<any>(null);
  const [completenessScore, setCompletenessScore] = useState(0);
  const [missingFields, setMissingFields] = useState<string[]>([]);

  useEffect(() => {
    if (!user) {
      router.push("/login");
      return;
    }

    // Initialize hole data
    const holes = parseInt(formData.holes) || 18;
    if (holeData.length === 0) {
      setHoleData(
        Array.from({ length: holes }, (_, i) => ({
          hole_number: i + 1,
          par: 4,
          yardages: { blue: 0, white: 0, gold: 0, red: 0 },
          handicap_index: i + 1,
          tee_locations: [],
          green_center: { lat: 0, lon: 0 },
          green_front: { lat: 0, lon: 0 },
          green_back: { lat: 0, lon: 0 },
          hazards: [],
          // Initialize polygon fields
          fairway: undefined,
          green: undefined,
          rough: undefined,
          bunkers: undefined,
          water_hazards: undefined,
          trees: undefined,
        }))
      );
    }
    
    // Load existing polygons from hole data (only once on mount)
    useEffect(() => {
      if (holeData.length > 0 && polygons.length === 0) {
        const loadedPolygons: PolygonData[] = [];
        holeData.forEach((hole) => {
          if (hole.fairway) {
            loadedPolygons.push({
              id: `fairway-${hole.hole_number}`,
              type: 'fairway',
              coordinates: hole.fairway,
              holeNumber: hole.hole_number,
            });
          }
          if (hole.green) {
            loadedPolygons.push({
              id: `green-${hole.hole_number}`,
              type: 'green',
              coordinates: hole.green,
              holeNumber: hole.hole_number,
            });
          }
          if (hole.rough) {
            loadedPolygons.push({
              id: `rough-${hole.hole_number}`,
              type: 'rough',
              coordinates: hole.rough,
              holeNumber: hole.hole_number,
            });
          }
          if (hole.bunkers) {
            hole.bunkers.forEach((bunker, idx) => {
              loadedPolygons.push({
                id: `bunker-${hole.hole_number}-${idx}`,
                type: 'bunker',
                coordinates: bunker.polygon,
                holeNumber: hole.hole_number,
              });
            });
          }
          if (hole.water_hazards) {
            hole.water_hazards.forEach((water, idx) => {
              loadedPolygons.push({
                id: `water-${hole.hole_number}-${idx}`,
                type: 'water',
                coordinates: water.polygon,
                holeNumber: hole.hole_number,
              });
            });
          }
          if (hole.trees) {
            hole.trees.forEach((tree, idx) => {
              loadedPolygons.push({
                id: `tree-${hole.hole_number}-${idx}`,
                type: 'tree',
                coordinates: tree.polygon,
                holeNumber: hole.hole_number,
              });
            });
          }
        });
        if (loadedPolygons.length > 0) {
          setPolygons(loadedPolygons);
        }
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [holeData.length]);
  }, [user, router, formData.holes]);

  // Real-time validation
  useEffect(() => {
    if (formData.name && formData.latitude && formData.longitude) {
      const validation = validateCourseData({
        name: formData.name,
        par: formData.par ? parseInt(formData.par) : undefined,
        holes: formData.holes ? parseInt(formData.holes) : undefined,
        latitude: parseFloat(formData.latitude),
        longitude: parseFloat(formData.longitude),
        hole_data: holeData,
      });
      setValidationResult(validation);
      
      // Calculate completeness (simplified)
      let score = 0;
      const missing: string[] = [];
      if (formData.name) score += 10; else missing.push('name');
      if (formData.latitude && formData.longitude) score += 20; else missing.push('location');
      if (formData.city || formData.state) score += 5; else missing.push('address');
      if (formData.par) score += 5; else missing.push('par');
      if (formData.course_rating && formData.slope_rating) score += 5; else missing.push('ratings');
      if (holeData.length > 0) score += 20; else missing.push('hole_data');
      if (holeData.some(h => h.tee_locations.length > 0)) score += 15; else missing.push('tee_locations');
      if (holeData.some(h => h.green_center.lat !== 0)) score += 15; else missing.push('green_locations');
      if (photos.length > 0) score += 5; else missing.push('photos');
      
      setCompletenessScore(Math.min(100, score));
      setMissingFields(missing);
    }
  }, [formData, holeData, photos]);

  const updateHoleData = (index: number, updates: Partial<HoleData>) => {
    setHoleData((prev) =>
      prev.map((hole, i) => (i === index ? { ...hole, ...updates } : hole))
    );
  };

  const addTeeLocation = (holeIndex: number) => {
    updateHoleData(holeIndex, {
      tee_locations: [
        ...holeData[holeIndex].tee_locations,
        { tee: "blue", lat: 0, lon: 0 },
      ],
    });
  };

  const removeTeeLocation = (holeIndex: number, teeIndex: number) => {
    updateHoleData(holeIndex, {
      tee_locations: holeData[holeIndex].tee_locations.filter(
        (_, i) => i !== teeIndex
      ),
    });
  };

  const addHazard = (holeIndex: number) => {
    updateHoleData(holeIndex, {
      hazards: [
        ...holeData[holeIndex].hazards,
        { type: "bunker", lat: 0, lon: 0 },
      ],
    });
  };

  const removeHazard = (holeIndex: number, hazardIndex: number) => {
    updateHoleData(holeIndex, {
      hazards: holeData[holeIndex].hazards.filter((_, i) => i !== hazardIndex),
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setSubmitting(true);

    try {
      // Validate required fields
      if (!formData.name || !formData.latitude || !formData.longitude) {
        throw new Error("Please fill in course name and location coordinates");
      }

      // Validate hole data
      const hasValidHoleData = holeData.some(
        (hole) =>
          hole.tee_locations.length > 0 &&
          (hole.green_center.lat !== 0 || hole.green_center.lon !== 0)
      );

      if (!hasValidHoleData) {
        throw new Error(
          "Please add at least basic GPS data (tee locations and green centers) for at least one hole"
        );
      }

      const contribution = {
        contributor_id: user.id,
        name: formData.name,
        city: formData.city || null,
        state: formData.state || null,
        country: formData.country,
        address: formData.address || null,
        phone: formData.phone || null,
        website: formData.website || null,
        course_rating: formData.course_rating
          ? parseFloat(formData.course_rating)
          : null,
        slope_rating: formData.slope_rating
          ? parseInt(formData.slope_rating)
          : null,
        par: formData.par ? parseInt(formData.par) : null,
        holes: formData.holes ? parseInt(formData.holes) : 18,
        latitude: formData.latitude ? parseFloat(formData.latitude) : null,
        longitude: formData.longitude ? parseFloat(formData.longitude) : null,
        hole_data: holeData.map((hole, index) => {
          // Merge polygon data from polygons state
          const holePolygons = polygons.filter(p => p.holeNumber === hole.hole_number);
          const updatedHole = { ...hole };
          
          holePolygons.forEach(poly => {
            if (poly.type === 'fairway') {
              updatedHole.fairway = poly.coordinates;
            } else if (poly.type === 'green') {
              updatedHole.green = poly.coordinates;
            } else if (poly.type === 'rough') {
              updatedHole.rough = poly.coordinates;
            } else if (poly.type === 'bunker') {
              if (!updatedHole.bunkers) updatedHole.bunkers = [];
              updatedHole.bunkers.push({ type: 'bunker', polygon: poly.coordinates });
            } else if (poly.type === 'water') {
              if (!updatedHole.water_hazards) updatedHole.water_hazards = [];
              updatedHole.water_hazards.push({ polygon: poly.coordinates });
            } else if (poly.type === 'tree') {
              if (!updatedHole.trees) updatedHole.trees = [];
              updatedHole.trees.push({ polygon: poly.coordinates });
            }
          });
          
          return updatedHole;
        }),
        photo_urls: photos,
        photos: photos.map(url => ({ url, uploaded_at: new Date().toISOString() })),
        status: "pending",
        source: "user",
      };

      const { data, error } = await supabase
        .from("course_contributions")
        .insert(contribution)
        .select()
        .single();

      if (error) throw error;

      setSuccess(true);
      setTimeout(() => {
        router.push(`/courses?contributed=${data.id}`);
      }, 2000);
    } catch (err: any) {
      console.error("Error submitting contribution:", err);
      alert(err.message || "Failed to submit course contribution");
    } finally {
      setSubmitting(false);
    }
  };

  if (success) {
    return (
      <div className="max-w-2xl mx-auto py-12">
        <Card className="p-8 text-center">
          <CheckCircle2 className="w-16 h-16 text-accent-green mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-foreground mb-2">
            Course Submitted!
          </h2>
          <p className="text-foreground-muted mb-6">
            Thank you for contributing! Your course submission is pending review.
            Once it receives 2-3 confirmations from other users, it will be
            verified and available to everyone.
          </p>
          <div className="flex gap-4 justify-center">
            <Button onClick={() => router.push("/courses")}>
              View Courses
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                setSuccess(false);
                setFormData({
                  name: "",
                  city: "",
                  state: "",
                  country: "USA",
                  address: "",
                  phone: "",
                  website: "",
                  course_rating: "",
                  slope_rating: "",
                  par: "72",
                  holes: "18",
                  latitude: "",
                  longitude: "",
                });
                setHoleData([]);
              }}
            >
              Submit Another
            </Button>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto py-8">
      <div className="mb-6">
        <Link
          href="/courses"
          className="text-foreground-muted hover:text-foreground inline-flex items-center gap-1"
        >
          ← Back to Courses
        </Link>
        <h1 className="text-3xl font-bold text-foreground mt-4">
          Contribute a Course
        </h1>
        <p className="text-foreground-muted mt-2">
          Help build our course database! Add GPS coordinates, hole data, and
          course information. Courses need 2-3 confirmations before being
          verified.
        </p>
      </div>

      {/* OSM Auto-fill */}
      <OSMAutofill
        onSelect={(data) => {
          setFormData({
            ...formData,
            name: data.name || formData.name,
            city: data.city || formData.city,
            state: data.state || formData.state,
            country: data.country || formData.country,
            address: data.address || formData.address,
            phone: data.phone || formData.phone,
            website: data.website || formData.website,
            latitude: data.latitude?.toString() || formData.latitude,
            longitude: data.longitude?.toString() || formData.longitude,
          });
        }}
        initialLat={formData.latitude ? parseFloat(formData.latitude) : undefined}
        initialLon={formData.longitude ? parseFloat(formData.longitude) : undefined}
      />

      {/* Data Completeness Indicator */}
      {completenessScore > 0 && (
        <Card className="p-4 mb-6">
          <DataCompletenessIndicator
            score={completenessScore}
            missingFields={missingFields}
            showDetails={true}
          />
        </Card>
      )}

      {/* Validation Warnings */}
      {validationResult && validationResult.warnings && validationResult.warnings.length > 0 && (
        <Card className="p-4 mb-6 bg-accent-amber/10 border-accent-amber/20">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-accent-amber mt-0.5" />
            <div>
              <p className="font-medium text-foreground mb-2">Validation Warnings:</p>
              <ul className="list-disc list-inside space-y-1 text-sm text-foreground-muted">
                {validationResult.warnings.map((warning: string, i: number) => (
                  <li key={i}>{warning}</li>
                ))}
              </ul>
            </div>
          </div>
        </Card>
      )}

      {/* Validation Errors */}
      {validationResult && validationResult.errors && validationResult.errors.length > 0 && (
        <Card className="p-4 mb-6 bg-red-500/10 border-red-500/20">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-red-500 mt-0.5" />
            <div>
              <p className="font-medium text-red-500 mb-2">Validation Errors:</p>
              <ul className="list-disc list-inside space-y-1 text-sm text-red-500">
                {validationResult.errors.map((error: string, i: number) => (
                  <li key={i}>{error}</li>
                ))}
              </ul>
            </div>
          </div>
        </Card>
      )}

      <Card className="p-6 mb-6 bg-accent-blue/10 border-accent-blue/20">
        <div className="flex items-start gap-3">
          <Info className="w-5 h-5 text-accent-blue mt-0.5" />
          <div className="text-sm text-foreground-muted">
            <p className="font-medium text-foreground mb-1">
              What you need to provide:
            </p>
            <ul className="list-disc list-inside space-y-1">
              <li>Course name and location (address or coordinates)</li>
              <li>
                GPS coordinates for tee boxes and greens (at minimum for a few
                holes)
              </li>
              <li>Hole pars and yardages (if available)</li>
              <li>Course rating and slope (if available)</li>
            </ul>
            <p className="mt-3">
              <strong>Tip:</strong> Use the OSM auto-fill above to import basic info, or use the map editor below to click and place markers.
            </p>
          </div>
        </div>
      </Card>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Basic Course Info */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Basic Information
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Course Name *
              </label>
              <Input
                value={formData.name}
                onChange={(e) =>
                  setFormData({ ...formData, name: e.target.value })
                }
                required
                placeholder="Pebble Beach Golf Links"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                City
              </label>
              <Input
                value={formData.city}
                onChange={(e) =>
                  setFormData({ ...formData, city: e.target.value })
                }
                placeholder="Pebble Beach"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                State
              </label>
              <Input
                value={formData.state}
                onChange={(e) =>
                  setFormData({ ...formData, state: e.target.value })
                }
                placeholder="CA"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Country
              </label>
              <Input
                value={formData.country}
                onChange={(e) =>
                  setFormData({ ...formData, country: e.target.value })
                }
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Address
              </label>
              <Input
                value={formData.address}
                onChange={(e) =>
                  setFormData({ ...formData, address: e.target.value })
                }
                placeholder="1700 17-Mile Drive"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Phone
              </label>
              <Input
                value={formData.phone}
                onChange={(e) =>
                  setFormData({ ...formData, phone: e.target.value })
                }
                placeholder="(831) 624-3811"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Website
              </label>
              <Input
                value={formData.website}
                onChange={(e) =>
                  setFormData({ ...formData, website: e.target.value })
                }
                type="url"
                placeholder="https://..."
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Number of Holes
              </label>
              <Input
                value={formData.holes}
                onChange={(e) => {
                  const holes = parseInt(e.target.value) || 18;
                  setFormData({ ...formData, holes: e.target.value });
                  // Update hole data array
                  if (holes !== holeData.length) {
                    setHoleData(
                      Array.from({ length: holes }, (_, i) => {
                        const existing = holeData[i];
                        return existing || {
                          hole_number: i + 1,
                          par: 4,
                          yardages: { blue: 0, white: 0, gold: 0, red: 0 },
                          handicap_index: i + 1,
                          tee_locations: [],
                          green_center: { lat: 0, lon: 0 },
                          green_front: { lat: 0, lon: 0 },
                          green_back: { lat: 0, lon: 0 },
                          hazards: [],
                        };
                      })
                    );
                  }
                }}
                type="number"
                min="9"
                max="36"
              />
            </div>
          </div>
        </Card>

        {/* Photo Upload */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Course Photos (Optional)
          </h2>
          <PhotoUpload
            photos={photos}
            onPhotosChange={setPhotos}
            maxPhotos={10}
          />
        </Card>

        {/* Course Ratings */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Course Ratings (Optional)
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Course Rating
              </label>
              <Input
                value={formData.course_rating}
                onChange={(e) =>
                  setFormData({ ...formData, course_rating: e.target.value })
                }
                type="number"
                step="0.1"
                placeholder="75.5"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Slope Rating
              </label>
              <Input
                value={formData.slope_rating}
                onChange={(e) =>
                  setFormData({ ...formData, slope_rating: e.target.value })
                }
                type="number"
                placeholder="145"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Par
              </label>
              <Input
                value={formData.par}
                onChange={(e) =>
                  setFormData({ ...formData, par: e.target.value })
                }
                type="number"
                placeholder="72"
              />
            </div>
          </div>
        </Card>

        {/* GPS Coordinates */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Course Location (GPS Coordinates) *
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Latitude *
              </label>
              <Input
                value={formData.latitude}
                onChange={(e) =>
                  setFormData({ ...formData, latitude: e.target.value })
                }
                type="number"
                step="any"
                required
                placeholder="36.5725"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Longitude *
              </label>
              <Input
                value={formData.longitude}
                onChange={(e) =>
                  setFormData({ ...formData, longitude: e.target.value })
                }
                type="number"
                step="any"
                required
                placeholder="-121.9486"
              />
            </div>
          </div>
          {formData.latitude && formData.longitude && (
            <div className="mt-4 space-y-4">
              <div className="flex items-center justify-between">
                <label className="block text-sm font-medium text-foreground">
                  Map Editor - Points & Polygons
              </label>
                <Button
                  type="button"
                  size="sm"
                  variant={showPolygonTool ? "default" : "outline"}
                  onClick={() => setShowPolygonTool(!showPolygonTool)}
                >
                  <Layers className="w-4 h-4 mr-2" />
                  {showPolygonTool ? "Hide Polygon Tool" : "Show Polygon Tool"}
                </Button>
              </div>
              
              {!showPolygonTool ? (
              <CourseMapEditor
                initialLat={parseFloat(formData.latitude)}
                initialLon={parseFloat(formData.longitude)}
                onMarkerAdd={(marker) => {
                  // Update the selected hole's GPS data
                  const holeIndex = currentHole - 1;
                  if (marker.type === 'tee') {
                    const existingTee = holeData[holeIndex]?.tee_locations.find(t => t.tee === marker.label);
                    if (existingTee) {
                      updateHoleData(holeIndex, {
                        tee_locations: holeData[holeIndex].tee_locations.map(t =>
                          t.tee === marker.label ? { ...t, lat: marker.position[0], lon: marker.position[1] } : t
                        )
                      });
                    } else {
                      updateHoleData(holeIndex, {
                        tee_locations: [
                          ...(holeData[holeIndex]?.tee_locations || []),
                          { tee: marker.label || 'blue', lat: marker.position[0], lon: marker.position[1] }
                        ]
                      });
                    }
                  } else if (marker.type === 'green_center') {
                    updateHoleData(holeIndex, {
                      green_center: { lat: marker.position[0], lon: marker.position[1] }
                    });
                  }
                }}
                markers={mapMarkers}
                currentHole={currentHole}
                mode="edit"
              />
              ) : (
                <PolygonDrawingTool
                  initialLat={parseFloat(formData.latitude)}
                  initialLon={parseFloat(formData.longitude)}
                  polygons={polygons.filter(p => p.holeNumber === currentHole)}
                  currentHole={currentHole}
                  mode="draw"
                  onPolygonAdd={(polygon) => {
                    setPolygons([...polygons, polygon]);
                    // Update hole data with polygon
                    const holeIndex = currentHole - 1;
                    const currentHoleData = holeData[holeIndex];
                    
                    if (polygon.type === 'fairway') {
                      updateHoleData(holeIndex, {
                        fairway: polygon.coordinates
                      });
                    } else if (polygon.type === 'green') {
                      updateHoleData(holeIndex, {
                        green: polygon.coordinates
                      });
                    } else if (polygon.type === 'rough') {
                      updateHoleData(holeIndex, {
                        rough: polygon.coordinates
                      });
                    } else if (polygon.type === 'bunker') {
                      updateHoleData(holeIndex, {
                        bunkers: [
                          ...(currentHoleData.bunkers || []),
                          { type: 'bunker', polygon: polygon.coordinates }
                        ]
                      });
                    } else if (polygon.type === 'water') {
                      updateHoleData(holeIndex, {
                        water_hazards: [
                          ...(currentHoleData.water_hazards || []),
                          { polygon: polygon.coordinates }
                        ]
                      });
                    } else if (polygon.type === 'tree') {
                      updateHoleData(holeIndex, {
                        trees: [
                          ...(currentHoleData.trees || []),
                          { polygon: polygon.coordinates }
                        ]
                      });
                    }
                  }}
                  onPolygonUpdate={(id, coordinates) => {
                    setPolygons(polygons.map(p => 
                      p.id === id ? { ...p, coordinates } : p
                    ));
                    // Update hole data
                    const polygon = polygons.find(p => p.id === id);
                    if (polygon) {
                      const holeIndex = (polygon.holeNumber || currentHole) - 1;
                      const currentHoleData = holeData[holeIndex];
                      
                      if (polygon.type === 'fairway') {
                        updateHoleData(holeIndex, { fairway: coordinates });
                      } else if (polygon.type === 'green') {
                        updateHoleData(holeIndex, { green: coordinates });
                      } else if (polygon.type === 'rough') {
                        updateHoleData(holeIndex, { rough: coordinates });
                      } else if (polygon.type === 'bunker') {
                        const bunkerIndex = currentHoleData.bunkers?.findIndex((_, i) => 
                          polygons.filter(p => p.holeNumber === polygon.holeNumber && p.type === 'bunker')[i]?.id === id
                        );
                        if (bunkerIndex !== undefined && bunkerIndex >= 0) {
                          const updatedBunkers = [...(currentHoleData.bunkers || [])];
                          updatedBunkers[bunkerIndex] = { type: 'bunker', polygon: coordinates };
                          updateHoleData(holeIndex, { bunkers: updatedBunkers });
                        }
                      }
                    }
                  }}
                  onPolygonDelete={(id) => {
                    setPolygons(polygons.filter(p => p.id !== id));
                    // Remove from hole data
                    const polygon = polygons.find(p => p.id === id);
                    if (polygon) {
                      const holeIndex = (polygon.holeNumber || currentHole) - 1;
                      const currentHoleData = holeData[holeIndex];
                      
                      if (polygon.type === 'fairway') {
                        updateHoleData(holeIndex, { fairway: undefined });
                      } else if (polygon.type === 'green') {
                        updateHoleData(holeIndex, { green: undefined });
                      } else if (polygon.type === 'rough') {
                        updateHoleData(holeIndex, { rough: undefined });
                      }
                    }
                  }}
                />
              )}
            </div>
          )}
        </Card>

        {/* Hole Data */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold text-foreground mb-4">
            Hole Data (GPS Coordinates)
          </h2>
          <p className="text-sm text-foreground-muted mb-4">
            Add GPS coordinates for tee boxes, greens, and hazards. At minimum,
            add data for a few holes to help others confirm the course.
          </p>

          <div className="space-y-6">
            {holeData.map((hole, holeIndex) => (
              <div
                key={holeIndex}
                className="border border-background-tertiary rounded-lg p-4"
              >
                <h3 className="font-medium text-foreground mb-3">
                  Hole {hole.hole_number}
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label className="block text-sm font-medium text-foreground mb-1">
                      Par
                    </label>
                    <Input
                      type="number"
                      min="3"
                      max="6"
                      value={hole.par}
                      onChange={(e) =>
                        updateHoleData(holeIndex, {
                          par: parseInt(e.target.value) || 4,
                        })
                      }
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-foreground mb-1">
                      Handicap Index
                    </label>
                    <Input
                      type="number"
                      min="1"
                      max="18"
                      value={hole.handicap_index}
                      onChange={(e) =>
                        updateHoleData(holeIndex, {
                          handicap_index: parseInt(e.target.value) || 1,
                        })
                      }
                    />
                  </div>
                </div>

                {/* Tee Locations */}
                <div className="mb-4">
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-sm font-medium text-foreground">
                      Tee Locations
                    </label>
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={() => addTeeLocation(holeIndex)}
                    >
                      <Plus className="w-4 h-4 mr-1" />
                      Add Tee
                    </Button>
                  </div>
                  {hole.tee_locations.map((tee, teeIndex) => (
                    <div
                      key={teeIndex}
                      className="flex gap-2 mb-2 items-end"
                    >
                      <Input
                        placeholder="Tee color (blue, white, etc.)"
                        value={tee.tee}
                        onChange={(e) => {
                          const newTees = [...hole.tee_locations];
                          newTees[teeIndex].tee = e.target.value;
                          updateHoleData(holeIndex, { tee_locations: newTees });
                        }}
                        className="flex-1"
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lat"
                        value={tee.lat || ""}
                        onChange={(e) => {
                          const newTees = [...hole.tee_locations];
                          newTees[teeIndex].lat = parseFloat(e.target.value) || 0;
                          updateHoleData(holeIndex, { tee_locations: newTees });
                        }}
                        className="w-24"
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lon"
                        value={tee.lon || ""}
                        onChange={(e) => {
                          const newTees = [...hole.tee_locations];
                          newTees[teeIndex].lon = parseFloat(e.target.value) || 0;
                          updateHoleData(holeIndex, { tee_locations: newTees });
                        }}
                        className="w-24"
                      />
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        onClick={() => removeTeeLocation(holeIndex, teeIndex)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </div>
                  ))}
                </div>

                {/* Green Locations */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label className="block text-sm font-medium text-foreground mb-1">
                      Green Center (Lat, Lon)
                    </label>
                    <div className="flex gap-2">
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lat"
                        value={hole.green_center.lat || ""}
                        onChange={(e) =>
                          updateHoleData(holeIndex, {
                            green_center: {
                              ...hole.green_center,
                              lat: parseFloat(e.target.value) || 0,
                            },
                          })
                        }
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lon"
                        value={hole.green_center.lon || ""}
                        onChange={(e) =>
                          updateHoleData(holeIndex, {
                            green_center: {
                              ...hole.green_center,
                              lon: parseFloat(e.target.value) || 0,
                            },
                          })
                        }
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-foreground mb-1">
                      Green Front (Lat, Lon)
                    </label>
                    <div className="flex gap-2">
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lat"
                        value={hole.green_front.lat || ""}
                        onChange={(e) =>
                          updateHoleData(holeIndex, {
                            green_front: {
                              ...hole.green_front,
                              lat: parseFloat(e.target.value) || 0,
                            },
                          })
                        }
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lon"
                        value={hole.green_front.lon || ""}
                        onChange={(e) =>
                          updateHoleData(holeIndex, {
                            green_front: {
                              ...hole.green_front,
                              lon: parseFloat(e.target.value) || 0,
                            },
                          })
                        }
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-foreground mb-1">
                      Green Back (Lat, Lon)
                    </label>
                    <div className="flex gap-2">
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lat"
                        value={hole.green_back.lat || ""}
                        onChange={(e) =>
                          updateHoleData(holeIndex, {
                            green_back: {
                              ...hole.green_back,
                              lat: parseFloat(e.target.value) || 0,
                            },
                          })
                        }
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lon"
                        value={hole.green_back.lon || ""}
                        onChange={(e) =>
                          updateHoleData(holeIndex, {
                            green_back: {
                              ...hole.green_back,
                              lon: parseFloat(e.target.value) || 0,
                            },
                          })
                        }
                      />
                    </div>
                  </div>
                </div>

                {/* Hazards */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-sm font-medium text-foreground">
                      Hazards (Optional)
                    </label>
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={() => addHazard(holeIndex)}
                    >
                      <Plus className="w-4 h-4 mr-1" />
                      Add Hazard
                    </Button>
                  </div>
                  {hole.hazards.map((hazard, hazardIndex) => (
                    <div key={hazardIndex} className="flex gap-2 mb-2 items-end">
                      <Input
                        placeholder="Type (bunker, water, etc.)"
                        value={hazard.type}
                        onChange={(e) => {
                          const newHazards = [...hole.hazards];
                          newHazards[hazardIndex].type = e.target.value;
                          updateHoleData(holeIndex, { hazards: newHazards });
                        }}
                        className="flex-1"
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lat"
                        value={hazard.lat || ""}
                        onChange={(e) => {
                          const newHazards = [...hole.hazards];
                          newHazards[hazardIndex].lat = parseFloat(e.target.value) || 0;
                          updateHoleData(holeIndex, { hazards: newHazards });
                        }}
                        className="w-24"
                      />
                      <Input
                        type="number"
                        step="any"
                        placeholder="Lon"
                        value={hazard.lon || ""}
                        onChange={(e) => {
                          const newHazards = [...hole.hazards];
                          newHazards[hazardIndex].lon = parseFloat(e.target.value) || 0;
                          updateHoleData(holeIndex, { hazards: newHazards });
                        }}
                        className="w-24"
                      />
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        onClick={() => removeHazard(holeIndex, hazardIndex)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </Card>

        {/* Submit Button */}
        <div className="flex gap-4">
          <Button
            type="submit"
            disabled={submitting}
            className="flex items-center gap-2"
          >
            {submitting ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                Submitting...
              </>
            ) : (
              <>
                <MapPin className="w-4 h-4" />
                Submit Course Contribution
              </>
            )}
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={() => router.push("/courses")}
          >
            Cancel
          </Button>
        </div>
      </form>
    </div>
  );
}
