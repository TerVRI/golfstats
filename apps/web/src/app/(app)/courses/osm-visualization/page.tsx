import { OSMCoursesVisualization } from "@/components/osm-courses-visualization";
import { Card } from "@/components/ui/card";
import { Globe, Info } from "lucide-react";

export default function OSMVisualizationPage() {
  return (
    <div className="container mx-auto py-8 px-4 space-y-6">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="p-3 bg-green-500/20 rounded-lg">
            <Globe className="w-6 h-6 text-green-500" />
          </div>
          <div>
            <h1 className="text-3xl font-bold text-foreground">
              OpenStreetMap Golf Courses
            </h1>
            <p className="text-foreground-muted">
              Explore {40_491.toLocaleString()}+ golf courses from around the world
            </p>
          </div>
        </div>
      </div>

      {/* Info Card */}
      <Card className="p-4 bg-blue-500/10 border-blue-500/20">
        <div className="flex items-start gap-3">
          <Info className="w-5 h-5 text-blue-500 mt-0.5" />
          <div className="flex-1">
            <p className="text-sm text-foreground">
              <strong>About this visualization:</strong> This map shows all golf courses imported from OpenStreetMap. 
              Courses are color-coded by status (green = approved, yellow = pending, gray = other). 
              Use the search and filters to explore courses by location or country.
            </p>
          </div>
        </div>
      </Card>

      {/* Visualization */}
      <OSMCoursesVisualization />
    </div>
  );
}
