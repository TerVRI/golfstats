"use client";

import { useEffect, useState } from "react";
import { MapContainer, TileLayer, Marker, Popup, Polygon, Circle, useMap, Polyline } from "react-leaflet";
import { LatLng, Icon } from "leaflet";
import "leaflet/dist/leaflet.css";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Select } from "@/components/ui/select";
import { MapPin, Flag, AlertTriangle, Layers, Eye, EyeOff } from "lucide-react";
import { cn } from "@/lib/utils";

// Fix for default marker icons in Next.js
if (typeof window !== "undefined") {
  delete (Icon.Default.prototype as any)._getIconUrl;
  Icon.Default.mergeOptions({
    iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
    iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  });
}

// Enhanced hole data structure with polygons
export interface HoleVisualizationData {
  hole_number: number;
  par: number;
  // Points
  tee_locations?: Array<{ tee: string; lat: number; lon: number }>;
  green_center?: { lat: number; lon: number };
  green_front?: { lat: number; lon: number };
  green_back?: { lat: number; lon: number };
  // Polygons (arrays of [lat, lon] coordinates)
  fairway?: Array<[number, number]>;
  green?: Array<[number, number]>;
  rough?: Array<[number, number]>;
  bunkers?: Array<{
    type: "bunker" | "sand_trap";
    polygon: Array<[number, number]>;
    center?: { lat: number; lon: number };
  }>;
  water_hazards?: Array<{
    polygon: Array<[number, number]>;
    center?: { lat: number; lon: number };
  }>;
  trees?: Array<{
    polygon: Array<[number, number]>;
    center?: { lat: number; lon: number };
  }>;
  // Yardage markers
  yardage_markers?: Array<{
    distance: number;
    lat: number;
    lon: number;
  }>;
}

interface CourseVisualizerProps {
  holeData: HoleVisualizationData[];
  initialHole?: number;
  center?: [number, number];
  zoom?: number;
  showSatellite?: boolean;
  mode?: "view" | "interactive";
  onHoleChange?: (holeNumber: number) => void;
  showLayers?: {
    fairway?: boolean;
    green?: boolean;
    rough?: boolean;
    bunkers?: boolean;
    water?: boolean;
    trees?: boolean;
    yardageMarkers?: boolean;
  };
}

function MapController({
  center,
  zoom,
}: {
  center: [number, number];
  zoom: number;
}) {
  const map = useMap();
  useEffect(() => {
    map.setView(center, zoom);
  }, [map, center, zoom]);
  return null;
}

export function CourseVisualizer({
  holeData,
  initialHole = 1,
  center,
  zoom = 15,
  showSatellite = false,
  mode = "view",
  onHoleChange,
  showLayers = {
    fairway: true,
    green: true,
    rough: true,
    bunkers: true,
    water: true,
    trees: false,
    yardageMarkers: true,
  },
}: CourseVisualizerProps) {
  const [selectedHole, setSelectedHole] = useState(initialHole);
  const [mapCenter, setMapCenter] = useState<[number, number]>(center || [40.7128, -74.0060]);
  const [mapZoom, setMapZoom] = useState(zoom);
  const [layers, setLayers] = useState(showLayers);

  const currentHole = holeData.find((h) => h.hole_number === selectedHole);

  // Calculate map center from hole data if not provided
  useEffect(() => {
    if (!center && currentHole) {
      if (currentHole.green_center) {
        setMapCenter([currentHole.green_center.lat, currentHole.green_center.lon]);
      } else if (currentHole.tee_locations && currentHole.tee_locations.length > 0) {
        setMapCenter([currentHole.tee_locations[0].lat, currentHole.tee_locations[0].lon]);
      }
    }
  }, [currentHole, center]);

  const handleHoleChange = (holeNumber: number) => {
    setSelectedHole(holeNumber);
    onHoleChange?.(holeNumber);
    
    // Center map on new hole
    const hole = holeData.find((h) => h.hole_number === holeNumber);
    if (hole) {
      if (hole.green_center) {
        setMapCenter([hole.green_center.lat, hole.green_center.lon]);
      } else if (hole.tee_locations && hole.tee_locations.length > 0) {
        setMapCenter([hole.tee_locations[0].lat, hole.tee_locations[0].lon]);
      }
      setMapZoom(16);
    }
  };

  const getTeeIcon = (teeColor: string) => {
    const colors: Record<string, string> = {
      black: "#000000",
      blue: "#3b82f6",
      white: "#ffffff",
      gold: "#fbbf24",
      red: "#ef4444",
    };
    const color = colors[teeColor.toLowerCase()] || "#3b82f6";
    
    return new Icon({
      iconUrl: `data:image/svg+xml;base64,${btoa(`
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" fill="${color}" stroke="white" stroke-width="2"/>
          <text x="12" y="16" font-size="10" fill="white" text-anchor="middle" font-weight="bold">T</text>
        </svg>
      `)}`,
      iconSize: [24, 24],
      iconAnchor: [12, 24],
    });
  };

  const getGreenIcon = () => {
    return new Icon({
      iconUrl: `data:image/svg+xml;base64,${btoa(`
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
          <circle cx="16" cy="16" r="14" fill="#10b981" stroke="white" stroke-width="2"/>
          <text x="16" y="20" font-size="14" fill="white" text-anchor="middle" font-weight="bold">G</text>
        </svg>
      `)}`,
      iconSize: [32, 32],
      iconAnchor: [16, 32],
    });
  };

  if (!currentHole) {
    return (
      <Card className="p-8 text-center">
        <p className="text-foreground-muted">No hole data available</p>
      </Card>
    );
  }

  return (
    <div className="w-full space-y-4">
      {/* Hole Selector */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Select
            value={selectedHole.toString()}
            onChange={(e) => handleHoleChange(parseInt(e.target.value))}
          >
            {holeData.map((hole) => (
              <option key={hole.hole_number} value={hole.hole_number}>
                Hole {hole.hole_number} - Par {hole.par}
              </option>
            ))}
          </Select>
        </div>
        
        {/* Layer Toggle */}
        <div className="flex items-center gap-2">
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, fairway: !layers.fairway })}
            className={cn(layers.fairway && "bg-accent-green/20")}
          >
            {layers.fairway ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Fairway</span>
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, green: !layers.green })}
            className={cn(layers.green && "bg-accent-green/20")}
          >
            {layers.green ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Green</span>
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, bunkers: !layers.bunkers })}
            className={cn(layers.bunkers && "bg-yellow-500/20")}
          >
            {layers.bunkers ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Bunkers</span>
          </Button>
        </div>
      </div>

      {/* Map */}
      <Card className="overflow-hidden p-0">
        <div className="w-full h-[600px] relative">
          <MapContainer
            center={mapCenter}
            zoom={mapZoom}
            style={{ height: "100%", width: "100%" }}
            scrollWheelZoom={true}
          >
            <MapController center={mapCenter} zoom={mapZoom} />
            
            {showSatellite ? (
              <TileLayer
                attribution='&copy; <a href="https://www.esri.com/">Esri</a>'
                url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
              />
            ) : (
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
            )}

            {/* Fairway Polygon */}
            {layers.fairway && currentHole.fairway && currentHole.fairway.length > 0 && (
              <Polygon
                positions={currentHole.fairway}
                pathOptions={{
                  color: "#22c55e",
                  fillColor: "#22c55e",
                  fillOpacity: 0.3,
                  weight: 2,
                }}
              >
                <Popup>Fairway - Hole {selectedHole}</Popup>
              </Polygon>
            )}

            {/* Rough Polygon */}
            {layers.rough && currentHole.rough && currentHole.rough.length > 0 && (
              <Polygon
                positions={currentHole.rough}
                pathOptions={{
                  color: "#84cc16",
                  fillColor: "#84cc16",
                  fillOpacity: 0.2,
                  weight: 1,
                  dashArray: "5, 5",
                }}
              >
                <Popup>Rough - Hole {selectedHole}</Popup>
              </Polygon>
            )}

            {/* Green Polygon */}
            {layers.green && currentHole.green && currentHole.green.length > 0 && (
              <Polygon
                positions={currentHole.green}
                pathOptions={{
                  color: "#10b981",
                  fillColor: "#10b981",
                  fillOpacity: 0.5,
                  weight: 2,
                }}
              >
                <Popup>Green - Hole {selectedHole}</Popup>
              </Polygon>
            )}

            {/* Bunkers */}
            {layers.bunkers &&
              currentHole.bunkers?.map((bunker, idx) => (
                <Polygon
                  key={`bunker-${idx}`}
                  positions={bunker.polygon}
                  pathOptions={{
                    color: "#fbbf24",
                    fillColor: "#fbbf24",
                    fillOpacity: 0.4,
                    weight: 2,
                  }}
                >
                  <Popup>Bunker - Hole {selectedHole}</Popup>
                </Polygon>
              ))}

            {/* Water Hazards */}
            {layers.water &&
              currentHole.water_hazards?.map((water, idx) => (
                <Polygon
                  key={`water-${idx}`}
                  positions={water.polygon}
                  pathOptions={{
                    color: "#3b82f6",
                    fillColor: "#3b82f6",
                    fillOpacity: 0.5,
                    weight: 2,
                  }}
                >
                  <Popup>Water Hazard - Hole {selectedHole}</Popup>
                </Polygon>
              ))}

            {/* Trees */}
            {layers.trees &&
              currentHole.trees?.map((tree, idx) => (
                <Polygon
                  key={`tree-${idx}`}
                  positions={tree.polygon}
                  pathOptions={{
                    color: "#16a34a",
                    fillColor: "#16a34a",
                    fillOpacity: 0.3,
                    weight: 1,
                  }}
                >
                  <Popup>Tree Area - Hole {selectedHole}</Popup>
                </Polygon>
              ))}

            {/* Tee Locations */}
            {currentHole.tee_locations?.map((tee, idx) => (
              <Marker
                key={`tee-${idx}`}
                position={[tee.lat, tee.lon]}
                icon={getTeeIcon(tee.tee)}
              >
                <Popup>
                  <div className="text-sm">
                    <div className="font-medium">{tee.tee.toUpperCase()} Tee</div>
                    <div className="text-xs text-gray-500">Hole {selectedHole}</div>
                  </div>
                </Popup>
              </Marker>
            ))}

            {/* Green Center Marker */}
            {currentHole.green_center && (
              <Marker
                position={[currentHole.green_center.lat, currentHole.green_center.lon]}
                icon={getGreenIcon()}
              >
                <Popup>
                  <div className="text-sm">
                    <div className="font-medium">Green Center</div>
                    <div className="text-xs text-gray-500">Hole {selectedHole}</div>
                  </div>
                </Popup>
              </Marker>
            )}

            {/* Yardage Markers */}
            {layers.yardageMarkers &&
              currentHole.yardage_markers?.map((marker, idx) => (
                <Circle
                  key={`yardage-${idx}`}
                  center={[marker.lat, marker.lon]}
                  radius={5}
                  pathOptions={{
                    color: "#ef4444",
                    fillColor: "#ef4444",
                    fillOpacity: 0.7,
                    weight: 2,
                  }}
                >
                  <Popup>
                    <div className="text-sm font-medium">{marker.distance} yards</div>
                  </Popup>
                </Circle>
              ))}

            {/* Tee to Green Line */}
            {currentHole.tee_locations &&
              currentHole.tee_locations.length > 0 &&
              currentHole.green_center && (
                <Polyline
                  positions={[
                    [currentHole.tee_locations[0].lat, currentHole.tee_locations[0].lon],
                    [currentHole.green_center.lat, currentHole.green_center.lon],
                  ]}
                  pathOptions={{
                    color: "#6366f1",
                    weight: 2,
                    dashArray: "10, 5",
                    opacity: 0.5,
                  }}
                />
              )}
          </MapContainer>
        </div>
      </Card>

      {/* Hole Info */}
      <Card className="p-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-semibold text-foreground">
              Hole {selectedHole} - Par {currentHole.par}
            </h3>
            {currentHole.yardage_markers && currentHole.yardage_markers.length > 0 && (
              <p className="text-sm text-foreground-muted">
                Yardage markers: {currentHole.yardage_markers.map((m) => m.distance).join(", ")} yards
              </p>
            )}
          </div>
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="outline"
              onClick={() => setMapZoom(Math.max(13, mapZoom - 1))}
            >
              Zoom Out
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setMapZoom(Math.min(20, mapZoom + 1))}
            >
              Zoom In
            </Button>
          </div>
        </div>
      </Card>
    </div>
  );
}
