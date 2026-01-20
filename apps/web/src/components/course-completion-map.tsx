"use client";

import { useEffect, useRef, useState } from "react";
import { MapPin } from "lucide-react";

interface CourseCompletionMapProps {
  initialLat?: number;
  initialLon?: number;
  onMapClick: (lat: number, lon: number) => void;
}

export default function CourseCompletionMap({
  initialLat,
  initialLon,
  onMapClick,
}: CourseCompletionMapProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const [map, setMap] = useState<any>(null);
  const [marker, setMarker] = useState<any>(null);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // Dynamically load Leaflet
    const loadMap = async () => {
      if (mapRef.current && !map) {
        try {
          const L = await import("leaflet");
          await import("leaflet/dist/leaflet.css");

          // Initialize map
          const newMap = L.map(mapRef.current).setView(
            initialLat && initialLon ? [initialLat, initialLon] : [0, 0],
            initialLat && initialLon ? 15 : 2
          );

          // Add tile layer
          L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
          }).addTo(newMap);

          // Add marker if initial coordinates exist
          if (initialLat && initialLon) {
            const newMarker = L.marker([initialLat, initialLon], {
              draggable: true,
            }).addTo(newMap);

            newMarker.on("dragend", () => {
              const position = newMarker.getLatLng();
              onMapClick(position.lat, position.lng);
            });

            setMarker(newMarker);
          }

          // Handle map clicks
          newMap.on("click", (e: any) => {
            const { lat, lng } = e.latlng;

            if (marker) {
              marker.setLatLng([lat, lng]);
            } else {
              const newMarker = L.marker([lat, lng], {
                draggable: true,
              }).addTo(newMap);

              newMarker.on("dragend", () => {
                const position = newMarker.getLatLng();
                onMapClick(position.lat, position.lng);
              });

              setMarker(newMarker);
            }

            onMapClick(lat, lng);
          });

          setMap(newMap);
          setIsLoaded(true);
        } catch (error) {
          console.error("Error loading map:", error);
        }
      }
    };

    loadMap();

    return () => {
      if (map) {
        map.remove();
      }
    };
  }, []);

  // Update marker position when initial coordinates change
  useEffect(() => {
    if (map && marker && initialLat && initialLon) {
      marker.setLatLng([initialLat, initialLon]);
      map.setView([initialLat, initialLon], 15);
    } else if (map && !marker && initialLat && initialLon) {
      const L = require("leaflet");
      const newMarker = L.marker([initialLat, initialLon], {
        draggable: true,
      }).addTo(map);

      newMarker.on("dragend", () => {
        const position = newMarker.getLatLng();
        onMapClick(position.lat, position.lng);
      });

      setMarker(newMarker);
      map.setView([initialLat, initialLon], 15);
    }
  }, [initialLat, initialLon, map, marker, onMapClick]);

  return (
    <div className="relative">
      <div ref={mapRef} className="h-[400px] w-full rounded-lg" />
      {!isLoaded && (
        <div className="absolute inset-0 flex items-center justify-center bg-background-secondary rounded-lg">
          <div className="text-center">
            <MapPin className="w-8 h-8 mx-auto mb-2 text-foreground-muted animate-pulse" />
            <p className="text-sm text-foreground-muted">Loading map...</p>
          </div>
        </div>
      )}
    </div>
  );
}
