"use client";

import { useMemo, useState } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Eye, EyeOff, ZoomIn, ZoomOut, RotateCcw, Download, Grid, Map } from "lucide-react";
import { cn } from "@/lib/utils";

// Reuse the same interface from course-visualizer
export interface HoleVisualizationData {
  hole_number: number;
  par: number;
  tee_locations?: Array<{ tee: string; lat: number; lon: number }>;
  green_center?: { lat: number; lon: number };
  green_front?: { lat: number; lon: number };
  green_back?: { lat: number; lon: number };
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
  yardage_markers?: Array<{
    distance: number;
    lat: number;
    lon: number;
  }>;
}

interface CourseSVGVisualizerProps {
  holeData: HoleVisualizationData[];
  initialHole?: number;
  width?: number;
  height?: number;
  showLayers?: {
    fairway?: boolean;
    green?: boolean;
    rough?: boolean;
    bunkers?: boolean;
    water?: boolean;
    trees?: boolean;
    yardageMarkers?: boolean;
    tees?: boolean;
    pins?: boolean;
  };
  mode?: "hole" | "overview"; // Show single hole or all holes
}

interface Bounds {
  minLat: number;
  maxLat: number;
  minLon: number;
  maxLon: number;
}

interface Point {
  x: number;
  y: number;
}

// Calculate bounding box for all coordinates in hole data
function calculateBounds(holeData: HoleVisualizationData[]): Bounds {
  let minLat = Infinity;
  let maxLat = -Infinity;
  let minLon = Infinity;
  let maxLon = -Infinity;

  const updateBounds = (lat: number, lon: number) => {
    minLat = Math.min(minLat, lat);
    maxLat = Math.max(maxLat, lat);
    minLon = Math.min(minLon, lon);
    maxLon = Math.max(maxLon, lon);
  };

  holeData.forEach((hole) => {
    // Tee locations
    hole.tee_locations?.forEach((tee) => {
      updateBounds(tee.lat, tee.lon);
    });

    // Green center/front/back
    if (hole.green_center) updateBounds(hole.green_center.lat, hole.green_center.lon);
    if (hole.green_front) updateBounds(hole.green_front.lat, hole.green_front.lon);
    if (hole.green_back) updateBounds(hole.green_back.lat, hole.green_back.lon);

    // Polygons
    hole.fairway?.forEach(([lat, lon]) => updateBounds(lat, lon));
    hole.green?.forEach(([lat, lon]) => updateBounds(lat, lon));
    hole.rough?.forEach(([lat, lon]) => updateBounds(lat, lon));

    // Bunkers
    hole.bunkers?.forEach((bunker) => {
      bunker.polygon.forEach(([lat, lon]) => updateBounds(lat, lon));
    });

    // Water hazards
    hole.water_hazards?.forEach((water) => {
      water.polygon.forEach(([lat, lon]) => updateBounds(lat, lon));
    });

    // Trees
    hole.trees?.forEach((tree) => {
      tree.polygon.forEach(([lat, lon]) => updateBounds(lat, lon));
    });

    // Yardage markers
    hole.yardage_markers?.forEach((marker) => {
      updateBounds(marker.lat, marker.lon);
    });
  });

  // Add padding (about 5% on each side)
  const latPadding = (maxLat - minLat) * 0.05 || 0.001;
  const lonPadding = (maxLon - minLon) * 0.05 || 0.001;

  return {
    minLat: minLat - latPadding,
    maxLat: maxLat + latPadding,
    minLon: minLon - lonPadding,
    maxLon: maxLon + lonPadding,
  };
}

// Convert GPS coordinates to SVG coordinates
function gpsToSVG(
  lat: number,
  lon: number,
  bounds: Bounds,
  width: number,
  height: number
): Point {
  const latRange = bounds.maxLat - bounds.minLat;
  const lonRange = bounds.maxLon - bounds.minLon;

  // Normalize to 0-1 range
  const normalizedLat = (lat - bounds.minLat) / latRange;
  const normalizedLon = (lon - bounds.minLon) / lonRange;

  // Convert to SVG coordinates (flip Y because SVG Y increases downward)
  const x = normalizedLon * width;
  const y = (1 - normalizedLat) * height; // Flip Y axis

  return { x, y };
}

// Convert polygon array to SVG path string
function polygonToPath(
  polygon: Array<[number, number]>,
  bounds: Bounds,
  svgWidth: number,
  svgHeight: number
): string {
  if (polygon.length === 0) return "";

  const points = polygon.map(([lat, lon]) => gpsToSVG(lat, lon, bounds, svgWidth, svgHeight));
  const path = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ");
  return `${path} Z`; // Close the path
}

// Get tee color
function getTeeColor(tee: string): string {
  const colors: Record<string, string> = {
    black: "#000000",
    blue: "#3b82f6",
    white: "#ffffff",
    gold: "#fbbf24",
    red: "#ef4444",
  };
  return colors[tee.toLowerCase()] || "#3b82f6";
}

export function CourseSVGVisualizer({
  holeData,
  initialHole = 1,
  width = 800,
  height = 600,
  showLayers = {
    fairway: true,
    green: true,
    rough: false,
    bunkers: true,
    water: true,
    trees: false,
    yardageMarkers: true,
    tees: true,
    pins: true,
  },
  mode = "hole",
}: CourseSVGVisualizerProps) {
  const [selectedHole, setSelectedHole] = useState(initialHole);
  const [layers, setLayers] = useState(showLayers);
  const [zoom, setZoom] = useState(1);
  const [viewMode, setViewMode] = useState<"hole" | "overview">(mode || "hole");

  // Filter hole data based on mode
  const displayHoles = useMemo(() => {
    if (viewMode === "overview") {
      return holeData;
    }
    return holeData.filter((h) => h.hole_number === selectedHole);
  }, [holeData, selectedHole, viewMode]);

  // Calculate bounds for the displayed holes
  const bounds = useMemo(() => {
    if (displayHoles.length === 0) {
      return {
        minLat: 0,
        maxLat: 0.001,
        minLon: 0,
        maxLon: 0.001,
      };
    }
    return calculateBounds(displayHoles);
  }, [displayHoles]);

  // Reset zoom
  const resetView = () => {
    setZoom(1);
  };

  // Calculate distance between two GPS points (Haversine formula)
  const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number): number => {
    const R = 6371e3; // Earth radius in meters
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in meters
  };

  // Convert meters to yards
  const metersToYards = (meters: number): number => {
    return meters * 1.09361;
  };

  // Export SVG as file
  const exportSVG = () => {
    const svgElement = document.querySelector('[data-svg-visualizer]') as SVGSVGElement;
    if (!svgElement) return;

    const svgData = new XMLSerializer().serializeToString(svgElement);
    const svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    const svgUrl = URL.createObjectURL(svgBlob);
    const downloadLink = document.createElement("a");
    downloadLink.href = svgUrl;
    downloadLink.download = `course-${viewMode === "overview" ? "overview" : `hole-${selectedHole}`}.svg`;
    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
    URL.revokeObjectURL(svgUrl);
  };

  // Export as PNG (requires canvas conversion)
  const exportPNG = async () => {
    const svgElement = document.querySelector('[data-svg-visualizer]') as SVGSVGElement;
    if (!svgElement) return;

    const svgData = new XMLSerializer().serializeToString(svgElement);
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");
    const img = new Image();

    canvas.width = width;
    canvas.height = height;

    return new Promise<void>((resolve) => {
      img.onload = () => {
        if (ctx) {
          ctx.fillStyle = "#f0f9f4";
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          ctx.drawImage(img, 0, 0);
          canvas.toBlob((blob) => {
            if (blob) {
              const url = URL.createObjectURL(blob);
              const downloadLink = document.createElement("a");
              downloadLink.href = url;
              downloadLink.download = `course-${viewMode === "overview" ? "overview" : `hole-${selectedHole}`}.png`;
              document.body.appendChild(downloadLink);
              downloadLink.click();
              document.body.removeChild(downloadLink);
              URL.revokeObjectURL(url);
            }
            resolve();
          });
        }
      };
      img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
    });
  };

  const currentHole = holeData.find((h) => h.hole_number === selectedHole);

  if (holeData.length === 0) {
    return (
      <Card className="p-8 text-center">
        <p className="text-foreground-muted">No hole data available</p>
      </Card>
    );
  }

  return (
    <div className="w-full space-y-4">
      {/* Controls */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div className="flex items-center gap-2">
          {/* View Mode Toggle */}
          {mode === undefined && (
            <>
              <Button
                size="sm"
                variant={viewMode === "hole" ? "default" : "outline"}
                onClick={() => setViewMode("hole")}
              >
                <Map className="w-4 h-4 mr-1" />
                Hole View
              </Button>
              <Button
                size="sm"
                variant={viewMode === "overview" ? "default" : "outline"}
                onClick={() => setViewMode("overview")}
              >
                <Grid className="w-4 h-4 mr-1" />
                Overview
              </Button>
            </>
          )}
          {viewMode === "hole" && (
            <Select
              value={selectedHole.toString()}
              onChange={(e) => setSelectedHole(parseInt(e.target.value))}
            >
              {holeData.map((hole) => (
                <option key={hole.hole_number} value={hole.hole_number}>
                  Hole {hole.hole_number} - Par {hole.par}
                </option>
              ))}
            </Select>
          )}
        </div>

        {/* Layer toggles */}
        <div className="flex items-center gap-2 flex-wrap">
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, fairway: !layers.fairway })}
            className={cn(layers.fairway && "bg-green-500/20")}
          >
            {layers.fairway ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Fairway</span>
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, green: !layers.green })}
            className={cn(layers.green && "bg-emerald-500/20")}
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
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, water: !layers.water })}
            className={cn(layers.water && "bg-blue-500/20")}
          >
            {layers.water ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Water</span>
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, tees: !layers.tees })}
          >
            {layers.tees ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Tees</span>
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setLayers({ ...layers, pins: !layers.pins })}
          >
            {layers.pins ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
            <span className="ml-1 hidden sm:inline">Pin</span>
          </Button>
        </div>

        {/* Zoom controls */}
        <div className="flex items-center gap-2">
          {viewMode === "hole" && (
            <>
              <Button size="sm" variant="outline" onClick={() => setZoom(Math.max(0.5, zoom - 0.1))}>
                <ZoomOut className="w-4 h-4" />
              </Button>
              <Button size="sm" variant="outline" onClick={() => setZoom(Math.min(3, zoom + 0.1))}>
                <ZoomIn className="w-4 h-4" />
              </Button>
              <Button size="sm" variant="outline" onClick={resetView}>
                <RotateCcw className="w-4 h-4" />
              </Button>
            </>
          )}
          {/* Export buttons */}
          <Button size="sm" variant="outline" onClick={exportSVG}>
            <Download className="w-4 h-4 mr-1" />
            <span className="hidden sm:inline">SVG</span>
          </Button>
          <Button size="sm" variant="outline" onClick={exportPNG}>
            <Download className="w-4 h-4 mr-1" />
            <span className="hidden sm:inline">PNG</span>
          </Button>
        </div>
      </div>

      {/* SVG Visualization */}
      <Card className="overflow-hidden p-0">
        <div className="w-full overflow-auto bg-gray-50" style={{ maxHeight: viewMode === "overview" ? "800px" : "600px" }}>
          <div
            style={{
              transform: viewMode === "hole" ? `scale(${zoom})` : "scale(1)",
              transformOrigin: "top left",
              display: "inline-block",
            }}
          >
            <svg
              data-svg-visualizer
              width={viewMode === "overview" ? width * 1.5 : width}
              height={viewMode === "overview" ? height * 1.5 : height}
              viewBox={`0 0 ${viewMode === "overview" ? width * 1.5 : width} ${viewMode === "overview" ? height * 1.5 : height}`}
              className="border border-gray-200"
              style={{ display: "block" }}
            >
            {/* Background */}
            <rect 
              width={viewMode === "overview" ? width * 1.5 : width} 
              height={viewMode === "overview" ? height * 1.5 : height} 
              fill="#f0f9f4" 
            />

            {/* Render each hole */}
            {displayHoles.map((hole) => {
              const holeNumber = hole.hole_number;
              // For overview mode, use overall bounds; for hole mode, use hole-specific bounds
              const holeBounds = viewMode === "overview" ? bounds : calculateBounds([hole]);
              const svgWidth = viewMode === "overview" ? width * 1.5 : width;
              const svgHeight = viewMode === "overview" ? height * 1.5 : height;

              return (
                <g key={holeNumber} data-hole={holeNumber}>
                  {/* Rough areas (if enabled) */}
                  {layers.rough &&
                    hole.rough &&
                    hole.rough.length > 0 && (
                      <path
                        d={polygonToPath(hole.rough, holeBounds, svgWidth, svgHeight)}
                        fill="#84cc16"
                        fillOpacity={0.2}
                        stroke="#84cc16"
                        strokeWidth={1}
                        strokeDasharray="5,5"
                      />
                    )}

                  {/* Fairway */}
                  {layers.fairway &&
                    hole.fairway &&
                    hole.fairway.length > 0 && (
                      <path
                        d={polygonToPath(hole.fairway, holeBounds, svgWidth, svgHeight)}
                        fill="#22c55e"
                        fillOpacity={0.4}
                        stroke="#16a34a"
                        strokeWidth={2}
                      />
                    )}

                  {/* Water hazards */}
                  {layers.water &&
                    hole.water_hazards?.map((water, idx) => (
                      <path
                        key={`water-${holeNumber}-${idx}`}
                        d={polygonToPath(water.polygon, holeBounds, svgWidth, svgHeight)}
                        fill="#3b82f6"
                        fillOpacity={0.5}
                        stroke="#2563eb"
                        strokeWidth={2}
                      />
                    ))}

                  {/* Bunkers */}
                  {layers.bunkers &&
                    hole.bunkers?.map((bunker, idx) => (
                      <path
                        key={`bunker-${holeNumber}-${idx}`}
                        d={polygonToPath(bunker.polygon, holeBounds, svgWidth, svgHeight)}
                        fill="#fbbf24"
                        fillOpacity={0.6}
                        stroke="#f59e0b"
                        strokeWidth={2}
                      />
                    ))}

                  {/* Green */}
                  {layers.green &&
                    hole.green &&
                    hole.green.length > 0 && (
                      <path
                        d={polygonToPath(hole.green, holeBounds, svgWidth, svgHeight)}
                        fill="#10b981"
                        fillOpacity={0.7}
                        stroke="#059669"
                        strokeWidth={2}
                      />
                    )}

                  {/* Trees */}
                  {layers.trees &&
                    hole.trees?.map((tree, idx) => (
                      <path
                        key={`tree-${holeNumber}-${idx}`}
                        d={polygonToPath(tree.polygon, holeBounds, svgWidth, svgHeight)}
                        fill="#16a34a"
                        fillOpacity={0.3}
                        stroke="#15803d"
                        strokeWidth={1}
                      />
                    ))}

                  {/* Tee locations */}
                  {layers.tees &&
                    hole.tee_locations?.map((tee, idx) => {
                      const point = gpsToSVG(tee.lat, tee.lon, holeBounds, svgWidth, svgHeight);
                      const color = getTeeColor(tee.tee);
                      return (
                        <g key={`tee-${holeNumber}-${idx}`}>
                          <circle
                            cx={point.x}
                            cy={point.y}
                            r={8}
                            fill={color}
                            stroke="white"
                            strokeWidth={2}
                          />
                          <text
                            x={point.x}
                            y={point.y + 4}
                            textAnchor="middle"
                            fontSize="10"
                            fill="white"
                            fontWeight="bold"
                          >
                            T
                          </text>
                          <text
                            x={point.x}
                            y={point.y + 20}
                            textAnchor="middle"
                            fontSize="8"
                            fill="#666"
                            fontWeight="bold"
                          >
                            {tee.tee.toUpperCase()}
                          </text>
                        </g>
                      );
                    })}

                  {/* Green center / Pin */}
                  {layers.pins && hole.green_center && (
                    <>
                      {(() => {
                        const point = gpsToSVG(
                          hole.green_center.lat,
                          hole.green_center.lon,
                          holeBounds,
                          svgWidth,
                          svgHeight
                        );
                        return (
                          <g>
                            <circle
                              cx={point.x}
                              cy={point.y}
                              r={6}
                              fill="#ef4444"
                              stroke="white"
                              strokeWidth={2}
                            />
                            <line
                              x1={point.x}
                              y1={point.y - 10}
                              x2={point.x}
                              y2={point.y - 20}
                              stroke="#ef4444"
                              strokeWidth={2}
                            />
                            <text
                              x={point.x}
                              y={point.y + 20}
                              textAnchor="middle"
                              fontSize="8"
                              fill="#666"
                              fontWeight="bold"
                            >
                              PIN
                            </text>
                          </g>
                        );
                      })()}
                    </>
                  )}

                  {/* Yardage markers */}
                  {layers.yardageMarkers &&
                    hole.yardage_markers?.map((marker, idx) => {
                      const point = gpsToSVG(marker.lat, marker.lon, holeBounds, svgWidth, svgHeight);
                      return (
                        <g key={`yardage-${holeNumber}-${idx}`}>
                          <circle
                            cx={point.x}
                            cy={point.y}
                            r={4}
                            fill="#ef4444"
                            stroke="white"
                            strokeWidth={1}
                          />
                          <text
                            x={point.x}
                            y={point.y - 8}
                            textAnchor="middle"
                            fontSize="9"
                            fill="#ef4444"
                            fontWeight="bold"
                          >
                            {marker.distance}
                          </text>
                        </g>
                      );
                    })}

                  {/* Simple tee-to-green line if no polygon data available */}
                  {!hole.fairway &&
                    !hole.green &&
                    hole.tee_locations &&
                    hole.tee_locations.length > 0 &&
                    hole.green_center && (
                      <>
                        <line
                          x1={gpsToSVG(hole.tee_locations[0].lat, hole.tee_locations[0].lon, holeBounds, svgWidth, svgHeight).x}
                          y1={gpsToSVG(hole.tee_locations[0].lat, hole.tee_locations[0].lon, holeBounds, svgWidth, svgHeight).y}
                          x2={gpsToSVG(hole.green_center.lat, hole.green_center.lon, holeBounds, svgWidth, svgHeight).x}
                          y2={gpsToSVG(hole.green_center.lat, hole.green_center.lon, holeBounds, svgWidth, svgHeight).y}
                          stroke="#22c55e"
                          strokeWidth={3}
                          strokeDasharray="10,5"
                          opacity={0.5}
                        />
                        {/* Distance label */}
                        {(() => {
                          const teePoint = gpsToSVG(
                            hole.tee_locations[0].lat,
                            hole.tee_locations[0].lon,
                            holeBounds,
                            svgWidth,
                            svgHeight
                          );
                          const greenPoint = gpsToSVG(
                            hole.green_center.lat,
                            hole.green_center.lon,
                            holeBounds,
                            svgWidth,
                            svgHeight
                          );
                          const midX = (teePoint.x + greenPoint.x) / 2;
                          const midY = (teePoint.y + greenPoint.y) / 2;
                          const distance = Math.round(
                            metersToYards(
                              calculateDistance(
                                hole.tee_locations[0].lat,
                                hole.tee_locations[0].lon,
                                hole.green_center.lat,
                                hole.green_center.lon
                              )
                            )
                          );
                          return (
                            <text
                              x={midX}
                              y={midY}
                              textAnchor="middle"
                              fontSize="12"
                              fill="#16a34a"
                              fontWeight="bold"
                              stroke="white"
                              strokeWidth={3}
                              paintOrder="stroke"
                            >
                              {distance} yds
                            </text>
                          );
                        })()}
                      </>
                    )}

                  {/* Hole number label (for overview mode) */}
                  {viewMode === "overview" && hole.green_center && (
                    <text
                      x={gpsToSVG(hole.green_center.lat, hole.green_center.lon, holeBounds, svgWidth, svgHeight).x}
                      y={gpsToSVG(hole.green_center.lat, hole.green_center.lon, holeBounds, svgWidth, svgHeight).y - 30}
                      textAnchor="middle"
                      fontSize="14"
                      fill="#000"
                      fontWeight="bold"
                      stroke="white"
                      strokeWidth={3}
                      paintOrder="stroke"
                    >
                      {hole.hole_number}
                    </text>
                  )}
                </g>
              );
            })}
            </svg>
          </div>
        </div>
      </Card>

      {/* Info */}
      {viewMode === "hole" && currentHole && (
        <Card className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="font-semibold text-foreground">
                Hole {selectedHole} - Par {currentHole.par}
              </h3>
              {currentHole.tee_locations && currentHole.tee_locations.length > 0 && (
                <p className="text-sm text-foreground-muted">
                  Tees: {currentHole.tee_locations.map((t) => t.tee).join(", ")}
                </p>
              )}
              {currentHole.tee_locations &&
                currentHole.tee_locations.length > 0 &&
                currentHole.green_center && (
                  <p className="text-sm text-foreground-muted">
                    Distance:{" "}
                    {currentHole.tee_locations
                      .map((tee) => {
                        const dist = Math.round(
                          metersToYards(
                            calculateDistance(
                              tee.lat,
                              tee.lon,
                              currentHole.green_center!.lat,
                              currentHole.green_center!.lon
                            )
                          )
                        );
                        return `${tee.tee}: ${dist} yds`;
                      })
                      .join(", ")}
                  </p>
                )}
              {currentHole.yardage_markers && currentHole.yardage_markers.length > 0 && (
                <p className="text-sm text-foreground-muted">
                  Yardage markers: {currentHole.yardage_markers.map((m) => m.distance).join(", ")} yards
                </p>
              )}
            </div>
          </div>
        </Card>
      )}

      {/* Overview Info */}
      {viewMode === "overview" && (
        <Card className="p-4">
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2 text-sm">
            {holeData.map((hole) => (
              <div key={hole.hole_number} className="text-center p-2 bg-background-secondary rounded">
                <div className="font-semibold">Hole {hole.hole_number}</div>
                <div className="text-foreground-muted">Par {hole.par}</div>
                {hole.tee_locations &&
                  hole.tee_locations.length > 0 &&
                  hole.green_center && (
                    <div className="text-xs text-foreground-muted mt-1">
                      {Math.round(
                        metersToYards(
                          calculateDistance(
                            hole.tee_locations[0].lat,
                            hole.tee_locations[0].lon,
                            hole.green_center.lat,
                            hole.green_center.lon
                          )
                        )
                      )}{" "}
                      yds
                    </div>
                  )}
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Legend */}
      <Card className="p-4">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-[#22c55e] border border-[#16a34a]"></div>
            <span>Fairway</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-[#10b981] border border-[#059669]"></div>
            <span>Green</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-[#fbbf24] border border-[#f59e0b]"></div>
            <span>Bunkers</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-[#3b82f6] border border-[#2563eb]"></div>
            <span>Water</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded-full bg-red-500 border-2 border-white"></div>
            <span>Pin</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded-full bg-blue-500 border-2 border-white"></div>
            <span>Tee</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-red-500"></div>
            <span>Yardage</span>
          </div>
        </div>
      </Card>
    </div>
  );
}
