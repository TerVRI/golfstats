"use client";

import { useEffect, useRef } from "react";
import { useMap } from "react-leaflet";
import L from "leaflet";

export interface OSMCourse {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  country?: string;
  city?: string;
  state?: string;
  source: string;
  status: string;
}

interface ClusterLayerProps {
  courses: OSMCourse[];
  showClusters: boolean;
  createGolfIcon: (color: string) => L.Icon;
}

export function ClusterLayer({ courses, showClusters, createGolfIcon }: ClusterLayerProps) {
  const map = useMap();
  const clusterGroupRef = useRef<L.MarkerClusterGroup | null>(null);

  useEffect(() => {
    if (!map) return;

    // Create cluster group
    if (!clusterGroupRef.current) {
      clusterGroupRef.current = L.markerClusterGroup({
        chunkedLoading: true,
        maxClusterRadius: 50,
        iconCreateFunction: (cluster) => {
          const count = cluster.getChildCount();
          let size = "small";
          let color = "#10b981";
          
          if (count > 100) {
            size = "large";
            color = "#ef4444";
          } else if (count > 50) {
            size = "medium";
            color = "#f59e0b";
          }
          
          return L.divIcon({
            html: `<div style="
              background-color: ${color};
              width: ${size === "large" ? "50px" : size === "medium" ? "40px" : "30px"};
              height: ${size === "large" ? "50px" : size === "medium" ? "40px" : "30px"};
              border-radius: 50%;
              border: 3px solid white;
              display: flex;
              align-items: center;
              justify-content: center;
              color: white;
              font-weight: bold;
              font-size: ${size === "large" ? "14px" : size === "medium" ? "12px" : "10px"};
              box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            ">${count}</div>`,
            className: "marker-cluster",
            iconSize: L.point(
              size === "large" ? 50 : size === "medium" ? 40 : 30,
              size === "large" ? 50 : size === "medium" ? 40 : 30
            ),
          });
        },
      });
    }

    const clusterGroup = clusterGroupRef.current;
    
    // Clear existing markers
    clusterGroup.clearLayers();

    if (showClusters && courses.length > 0) {
      // Add markers to cluster group
      courses.forEach((course) => {
        const marker = L.marker(
          [course.latitude, course.longitude],
          {
            icon: createGolfIcon(
              course.status === "approved" ? "#10b981" : 
              course.status === "pending" ? "#f59e0b" : 
              "#6b7280"
            ),
          }
        );

        const popupContent = `
          <div style="padding: 8px; min-width: 200px;">
            <h3 style="font-weight: 600; margin-bottom: 4px; color: var(--foreground);">${course.name}</h3>
            ${course.city ? `<p style="font-size: 0.875rem; color: var(--foreground-muted);">${[course.city, course.state, course.country].filter(Boolean).join(", ")}</p>` : ""}
            <div style="margin-top: 8px; display: flex; align-items: center; gap: 8px;">
              <span style="padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; ${
                course.status === "approved" ? "background-color: rgba(16, 185, 129, 0.2); color: rgb(16, 185, 129);" :
                course.status === "pending" ? "background-color: rgba(245, 158, 11, 0.2); color: rgb(245, 158, 11);" :
                "background-color: rgba(107, 114, 128, 0.2); color: rgb(107, 114, 128);"
              }">${course.status}</span>
              <span style="font-size: 0.75rem; color: var(--foreground-muted);">OSM</span>
            </div>
          </div>
        `;
        
        marker.bindPopup(popupContent);
        clusterGroup.addLayer(marker);
      });

      // Add cluster group to map
      clusterGroup.addTo(map);
    }

    return () => {
      if (clusterGroup) {
        map.removeLayer(clusterGroup);
      }
    };
  }, [map, courses, showClusters, createGolfIcon]);

  return null;
}
