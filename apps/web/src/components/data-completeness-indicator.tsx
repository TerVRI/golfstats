"use client";

import { Progress } from "@/components/ui/progress";
import { CheckCircle2, XCircle, AlertCircle } from "lucide-react";

interface DataCompletenessIndicatorProps {
  score: number; // 0-100
  missingFields?: string[];
  showDetails?: boolean;
}

export function DataCompletenessIndicator({
  score,
  missingFields = [],
  showDetails = false,
}: DataCompletenessIndicatorProps) {
  const getColor = () => {
    if (score >= 80) return "text-accent-green";
    if (score >= 50) return "text-accent-amber";
    return "text-red-500";
  };

  const getStatusIcon = () => {
    if (score >= 80) return <CheckCircle2 className="w-4 h-4 text-accent-green" />;
    if (score >= 50) return <AlertCircle className="w-4 h-4 text-accent-amber" />;
    return <XCircle className="w-4 h-4 text-red-500" />;
  };

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-foreground">Data Completeness</span>
          {getStatusIcon()}
        </div>
        <span className={`text-sm font-bold ${getColor()}`}>{score}%</span>
      </div>
      <Progress value={score} className="h-2" />
      {showDetails && missingFields.length > 0 && (
        <div className="mt-2 p-3 bg-background-secondary rounded-lg">
          <p className="text-xs font-medium text-foreground-muted mb-2">Missing fields:</p>
          <ul className="space-y-1">
            {missingFields.map((field, index) => (
              <li key={index} className="text-xs text-foreground-muted flex items-center gap-1">
                <XCircle className="w-3 h-3" />
                {field.replace("_", " ")}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
