"use client";

import { useState, useRef, useEffect } from "react";
import { MapContainer, TileLayer, Polygon, Polyline, useMap, Circle, Popup } from "react-leaflet";
import { LatLng } from "leaflet";
import "leaflet/dist/leaflet.css";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Select } from "@/components/ui/select";
import {
  MapPin,
  Layers,
  Trash2,
  Check,
  X,
  Edit2,
  Save,
  Undo2,
  Eye,
  EyeOff,
} from "lucide-react";
import { cn } from "@/lib/utils";

export type PolygonType =
  | "fairway"
  | "green"
  | "rough"
  | "bunker"
  | "water"
  | "tree";

export interface PolygonData {
  id: string;
  type: PolygonType;
  coordinates: Array<[number, number]>;
  holeNumber?: number;
}

interface PolygonDrawingToolProps {
  initialLat?: number;
  initialLon?: number;
  initialZoom?: number;
  polygons?: PolygonData[];
  onPolygonAdd?: (polygon: PolygonData) => void;
  onPolygonUpdate?: (id: string, coordinates: Array<[number, number]>) => void;
  onPolygonDelete?: (id: string) => void;
  currentHole?: number;
  showSatellite?: boolean;
  mode?: "draw" | "edit" | "view";
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

export function PolygonDrawingTool({
  initialLat = 40.7128,
  initialLon = -74.0060,
  initialZoom = 15,
  polygons = [],
  onPolygonAdd,
  onPolygonUpdate,
  onPolygonDelete,
  currentHole,
  showSatellite = false,
  mode = "draw",
}: PolygonDrawingToolProps) {
  const [mapCenter, setMapCenter] = useState<[number, number]>([initialLat, initialLon]);
  const [mapZoom, setMapZoom] = useState(initialZoom);
  const [selectedType, setSelectedType] = useState<PolygonType>("fairway");
  const [drawingPolygon, setDrawingPolygon] = useState<Array<[number, number]>>([]);
  const [isDrawing, setIsDrawing] = useState(false);
  const [editingPolygonId, setEditingPolygonId] = useState<string | null>(null);
  const [showLayers, setShowLayers] = useState({
    fairway: true,
    green: true,
    rough: true,
    bunkers: true,
    water: true,
    trees: true,
  });
  const polygonIdCounter = useRef(0);

  const getPolygonColor = (type: PolygonType) => {
    const colors: Record<PolygonType, { fill: string; stroke: string }> = {
      fairway: { fill: "#22c55e", stroke: "#16a34a" },
      green: { fill: "#10b981", stroke: "#059669" },
      rough: { fill: "#84cc16", stroke: "#65a30d" },
      bunker: { fill: "#fbbf24", stroke: "#f59e0b" },
      water: { fill: "#3b82f6", stroke: "#2563eb" },
      tree: { fill: "#16a34a", stroke: "#15803d" },
    };
    return colors[type];
  };

  const handleMapClick = (e: any) => {
    if (mode === "view" || !isDrawing) return;

    const { lat, lng } = e.latlng;
    const newPoint: [number, number] = [lat, lng];

    setDrawingPolygon((prev) => [...prev, newPoint]);
  };

  const finishDrawing = () => {
    if (drawingPolygon.length < 3) {
      alert("A polygon needs at least 3 points");
      return;
    }

    const newPolygon: PolygonData = {
      id: `polygon-${polygonIdCounter.current++}`,
      type: selectedType,
      coordinates: [...drawingPolygon, drawingPolygon[0]], // Close the polygon
      holeNumber: currentHole,
    };

    onPolygonAdd?.(newPolygon);
    setDrawingPolygon([]);
    setIsDrawing(false);
  };

  const cancelDrawing = () => {
    setDrawingPolygon([]);
    setIsDrawing(false);
  };

  const startDrawing = () => {
    setIsDrawing(true);
    setDrawingPolygon([]);
  };

  const startEditing = (polygonId: string) => {
    const polygon = polygons.find((p) => p.id === polygonId);
    if (polygon) {
      setEditingPolygonId(polygonId);
      setDrawingPolygon(polygon.coordinates.slice(0, -1)); // Remove closing point
      setIsDrawing(true);
    }
  };

  const saveEditing = () => {
    if (editingPolygonId && drawingPolygon.length >= 3) {
      onPolygonUpdate?.(editingPolygonId, [...drawingPolygon, drawingPolygon[0]]);
      setEditingPolygonId(null);
      setDrawingPolygon([]);
      setIsDrawing(false);
    }
  };

  const deletePolygon = (id: string) => {
    if (confirm("Delete this polygon?")) {
      onPolygonDelete?.(id);
    }
  };

  const filteredPolygons = polygons.filter((p) => {
    if (currentHole && p.holeNumber !== currentHole) return false;
    return showLayers[p.type] ?? true;
  });

  return (
    <div className="w-full space-y-4">
      {/* Controls */}
      <Card className="p-4">
        <div className="flex flex-wrap items-center gap-4">
          {/* Drawing Mode Controls */}
          {mode === "draw" && (
            <>
              <div className="flex items-center gap-2">
                <Select
                  value={selectedType}
                  onChange={(e) => setSelectedType(e.target.value as PolygonType)}
                  disabled={isDrawing}
                >
                  <option value="fairway">Fairway</option>
                  <option value="green">Green</option>
                  <option value="rough">Rough</option>
                  <option value="bunker">Bunker</option>
                  <option value="water">Water Hazard</option>
                  <option value="tree">Tree Area</option>
                </Select>
              </div>

              {!isDrawing ? (
                <Button onClick={startDrawing} size="sm">
                  <Layers className="w-4 h-4 mr-2" />
                  Start Drawing
                </Button>
              ) : (
                <div className="flex gap-2">
                  <Button onClick={finishDrawing} size="sm" variant="default">
                    <Check className="w-4 h-4 mr-2" />
                    Finish ({drawingPolygon.length} points)
                  </Button>
                  <Button onClick={cancelDrawing} size="sm" variant="outline">
                    <X className="w-4 h-4 mr-2" />
                    Cancel
                  </Button>
                </div>
              )}

              {editingPolygonId && (
                <Button onClick={saveEditing} size="sm" variant="default">
                  <Save className="w-4 h-4 mr-2" />
                  Save Changes
                </Button>
              )}
            </>
          )}

          {/* Layer Toggles */}
          <div className="flex gap-2 ml-auto">
            <Button
              size="sm"
              variant="outline"
              onClick={() => setShowLayers({ ...showLayers, fairway: !showLayers.fairway })}
              className={cn(showLayers.fairway && "bg-green-500/20")}
            >
              {showLayers.fairway ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setShowLayers({ ...showLayers, green: !showLayers.green })}
              className={cn(showLayers.green && "bg-green-500/20")}
            >
              {showLayers.green ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setShowLayers({ ...showLayers, bunkers: !showLayers.bunkers })}
              className={cn(showLayers.bunkers && "bg-yellow-500/20")}
            >
              {showLayers.bunkers ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            </Button>
          </div>
        </div>

        {isDrawing && (
          <div className="mt-3 p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg">
            <p className="text-sm text-blue-300">
              <strong>Drawing {selectedType}:</strong> Click on the map to add points. Need at least 3 points to finish.
            </p>
            <p className="text-xs text-blue-400 mt-1">
              Points: {drawingPolygon.length} | Click "Finish" when done
            </p>
          </div>
        )}
      </Card>

      {/* Map */}
      <Card className="overflow-hidden p-0">
        <div className="w-full h-[600px] relative">
          <MapContainer
            center={mapCenter}
            zoom={mapZoom}
            style={{ height: "100%", width: "100%" }}
            onClick={handleMapClick}
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

            {/* Existing Polygons */}
            {filteredPolygons.map((polygon) => {
              const colors = getPolygonColor(polygon.type);
              return (
                <Polygon
                  key={polygon.id}
                  positions={polygon.coordinates}
                  pathOptions={{
                    color: colors.stroke,
                    fillColor: colors.fill,
                    fillOpacity: polygon.type === "green" ? 0.5 : 0.3,
                    weight: 2,
                  }}
                >
                  {mode === "edit" && (
                    <Popup>
                      <div className="p-2">
                        <div className="font-medium capitalize">{polygon.type}</div>
                        {polygon.holeNumber && <div>Hole {polygon.holeNumber}</div>}
                        <div className="flex gap-2 mt-2">
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => startEditing(polygon.id)}
                          >
                            <Edit2 className="w-3 h-3 mr-1" />
                            Edit
                          </Button>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => deletePolygon(polygon.id)}
                          >
                            <Trash2 className="w-3 h-3 mr-1" />
                            Delete
                          </Button>
                        </div>
                      </div>
                    </Popup>
                  )}
                </Polygon>
              );
            })}

            {/* Drawing Polygon (in progress) */}
            {isDrawing && drawingPolygon.length > 0 && (
              <>
                {/* Points */}
                {drawingPolygon.map((point, idx) => (
                  <Circle
                    key={idx}
                    center={point}
                    radius={5}
                    pathOptions={{
                      color: "#ef4444",
                      fillColor: "#ef4444",
                      fillOpacity: 0.8,
                      weight: 2,
                    }}
                  />
                ))}

                {/* Preview Line */}
                {drawingPolygon.length > 1 && (
                  <Polyline
                    positions={drawingPolygon}
                    pathOptions={{
                      color: "#ef4444",
                      weight: 2,
                      dashArray: "5, 5",
                    }}
                  />
                )}

                {/* Closing line to first point */}
                {drawingPolygon.length >= 2 && (
                  <Polyline
                    positions={[drawingPolygon[drawingPolygon.length - 1], drawingPolygon[0]]}
                    pathOptions={{
                      color: "#ef4444",
                      weight: 2,
                      dashArray: "10, 5",
                    }}
                  />
                )}
              </>
            )}
          </MapContainer>
        </div>
      </Card>

      {/* Instructions */}
      {mode === "draw" && !isDrawing && (
        <Card className="p-4">
          <div className="text-sm text-foreground-muted">
            <p className="font-medium mb-2">How to draw polygons:</p>
            <ol className="list-decimal list-inside space-y-1">
              <li>Select the polygon type (fairway, green, etc.)</li>
              <li>Click "Start Drawing"</li>
              <li>Click on the map to add points (minimum 3 points)</li>
              <li>Click "Finish" to complete the polygon</li>
            </ol>
          </div>
        </Card>
      )}

      {/* Polygon List */}
      {polygons.length > 0 && (
        <Card className="p-4">
          <h3 className="font-semibold text-foreground mb-3">
            Polygons ({polygons.length})
          </h3>
          <div className="space-y-2 max-h-48 overflow-y-auto">
            {polygons.map((polygon) => {
              const colors = getPolygonColor(polygon.type);
              return (
                <div
                  key={polygon.id}
                  className="flex items-center justify-between p-2 bg-background-secondary rounded-lg"
                >
                  <div className="flex items-center gap-2">
                    <div
                      className="w-4 h-4 rounded"
                      style={{ backgroundColor: colors.fill }}
                    />
                    <span className="text-sm capitalize">{polygon.type}</span>
                    {polygon.holeNumber && (
                      <span className="text-xs text-foreground-muted">
                        (Hole {polygon.holeNumber})
                      </span>
                    )}
                    <span className="text-xs text-foreground-muted">
                      ({polygon.coordinates.length - 1} points)
                    </span>
                  </div>
                  {mode === "edit" && (
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => startEditing(polygon.id)}
                      >
                        <Edit2 className="w-3 h-3" />
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => deletePolygon(polygon.id)}
                      >
                        <Trash2 className="w-3 h-3" />
                      </Button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </Card>
      )}
    </div>
  );
}
