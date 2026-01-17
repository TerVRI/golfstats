"use client";

import { useEffect, useState, useRef } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap, Circle } from "react-leaflet";
import { LatLng, Icon } from "leaflet";
import "leaflet/dist/leaflet.css";
import { Button } from "@/components/ui/button";
import { Trash2, MapPin, Flag, AlertTriangle } from "lucide-react";

// Fix for default marker icons in Next.js
if (typeof window !== "undefined") {
  delete (Icon.Default.prototype as any)._getIconUrl;
  Icon.Default.mergeOptions({
    iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
    iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  });
}

interface MapMarker {
  id: string;
  type: "tee" | "green_center" | "green_front" | "green_back" | "hazard";
  position: [number, number];
  label?: string;
  holeNumber?: number;
}

interface CourseMapEditorProps {
  initialLat?: number;
  initialLon?: number;
  initialZoom?: number;
  markers?: MapMarker[];
  onMarkerAdd?: (marker: MapMarker) => void;
  onMarkerUpdate?: (id: string, position: [number, number]) => void;
  onMarkerDelete?: (id: string) => void;
  onMapClick?: (lat: number, lon: number) => void;
  mode?: "view" | "edit";
  currentHole?: number;
  showSatellite?: boolean;
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

export function CourseMapEditor({
  initialLat = 40.7128,
  initialLon = -74.0060,
  initialZoom = 15,
  markers = [],
  onMarkerAdd,
  onMarkerUpdate,
  onMarkerDelete,
  onMapClick,
  mode = "edit",
  currentHole,
  showSatellite = false,
}: CourseMapEditorProps) {
  const [mapCenter, setMapCenter] = useState<[number, number]>([initialLat, initialLon]);
  const [mapZoom, setMapZoom] = useState(initialZoom);
  const [selectedMarkerType, setSelectedMarkerType] = useState<MapMarker["type"]>("tee");
  const markerIdCounter = useRef(0);

  const getMarkerIcon = (type: MapMarker["type"]) => {
    const colors: Record<MapMarker["type"], string> = {
      tee: "#3b82f6", // blue
      green_center: "#10b981", // green
      green_front: "#10b981",
      green_back: "#10b981",
      hazard: "#ef4444", // red
    };

    return new Icon({
      iconUrl: `data:image/svg+xml;base64,${btoa(`
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
          <circle cx="16" cy="16" r="12" fill="${colors[type]}" stroke="white" stroke-width="2"/>
          <text x="16" y="20" font-size="12" fill="white" text-anchor="middle" font-weight="bold">${type === "tee" ? "T" : type === "green_center" ? "G" : type === "hazard" ? "!" : ""}</text>
        </svg>
      `)}`,
      iconSize: [32, 32],
      iconAnchor: [16, 32],
      popupAnchor: [0, -32],
    });
  };

  const handleMapClick = (e: any) => {
    if (mode === "view" || !onMarkerAdd) return;

    const { lat, lng } = e.latlng;
    const newMarker: MapMarker = {
      id: `marker-${markerIdCounter.current++}`,
      type: selectedMarkerType,
      position: [lat, lng],
      holeNumber: currentHole,
    };

    onMarkerAdd(newMarker);
    if (onMapClick) {
      onMapClick(lat, lng);
    }
  };

  const handleMarkerDragEnd = (markerId: string, e: any) => {
    if (!onMarkerUpdate) return;
    const { lat, lng } = e.target.getLatLng();
    onMarkerUpdate(markerId, [lat, lng]);
  };

  return (
    <div className="w-full h-[500px] rounded-lg overflow-hidden border border-background-tertiary relative">
      <MapContainer
        center={mapCenter}
        zoom={mapZoom}
        style={{ height: "100%", width: "100%" }}
        onClick={handleMapClick}
      >
        <MapController center={mapCenter} zoom={mapZoom} />
        
        {showSatellite ? (
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
          />
        ) : (
          <>
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
          </>
        )}

        {markers.map((marker) => (
          <Marker
            key={marker.id}
            position={marker.position}
            icon={getMarkerIcon(marker.type)}
            draggable={mode === "edit"}
            eventHandlers={{
              dragend: (e) => handleMarkerDragEnd(marker.id, e),
            }}
          >
            <Popup>
              <div className="text-sm">
                <div className="font-medium">{marker.type.replace("_", " ")}</div>
                {marker.holeNumber && <div>Hole {marker.holeNumber}</div>}
                <div className="text-xs text-gray-500">
                  {marker.position[0].toFixed(6)}, {marker.position[1].toFixed(6)}
                </div>
                {mode === "edit" && onMarkerDelete && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => onMarkerDelete(marker.id)}
                    className="mt-2"
                  >
                    <Trash2 className="w-3 h-3 mr-1" />
                    Delete
                  </Button>
                )}
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>

      {mode === "edit" && (
        <div className="absolute top-4 left-4 z-[1000] bg-background-secondary p-3 rounded-lg shadow-lg border border-background-tertiary">
          <div className="text-sm font-medium text-foreground mb-2">Add Marker</div>
          <div className="space-y-2">
            <Button
              size="sm"
              variant={selectedMarkerType === "tee" ? "default" : "outline"}
              onClick={() => setSelectedMarkerType("tee")}
              className="w-full"
            >
              <MapPin className="w-3 h-3 mr-1" />
              Tee Box
            </Button>
            <Button
              size="sm"
              variant={selectedMarkerType === "green_center" ? "default" : "outline"}
              onClick={() => setSelectedMarkerType("green_center")}
              className="w-full"
            >
              <Flag className="w-3 h-3 mr-1" />
              Green Center
            </Button>
            <Button
              size="sm"
              variant={selectedMarkerType === "hazard" ? "default" : "outline"}
              onClick={() => setSelectedMarkerType("hazard")}
              className="w-full"
            >
              <AlertTriangle className="w-3 h-3 mr-1" />
              Hazard
            </Button>
          </div>
          <div className="mt-3 text-xs text-foreground-muted">
            Click on map to place marker
          </div>
        </div>
      )}

      <div className="absolute top-4 right-4 z-[1000] bg-background-secondary p-2 rounded-lg shadow-lg">
        <Button
          size="sm"
          variant="outline"
          onClick={() => {
            if (navigator.geolocation) {
              navigator.geolocation.getCurrentPosition((position) => {
                setMapCenter([position.coords.latitude, position.coords.longitude]);
                setMapZoom(18);
              });
            }
          }}
        >
          <MapPin className="w-4 h-4" />
          My Location
        </Button>
      </div>
    </div>
  );
}
