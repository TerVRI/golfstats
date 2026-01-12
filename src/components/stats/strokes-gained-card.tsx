"use client";

import { cn, formatSG, getSGColor, getSGBgColor } from "@/lib/utils";
import { Card, CardContent } from "@/components/ui";
import { TrendingUp, TrendingDown, Minus, Target, Flag, CircleDot, Crosshair } from "lucide-react";

interface StrokesGainedCardProps {
  category: "total" | "off_tee" | "approach" | "around_green" | "putting";
  value: number;
  label: string;
  description?: string;
  showTrend?: boolean;
  trend?: number;
  className?: string;
}

const categoryIcons = {
  total: Target,
  off_tee: TrendingUp,
  approach: Crosshair,
  around_green: Flag,
  putting: CircleDot,
};

const categoryColors = {
  total: "from-accent-green to-accent-blue",
  off_tee: "from-blue-500 to-cyan-400",
  approach: "from-purple-500 to-pink-400",
  around_green: "from-amber-500 to-orange-400",
  putting: "from-emerald-500 to-teal-400",
};

export function StrokesGainedCard({
  category,
  value,
  label,
  description,
  showTrend = false,
  trend = 0,
  className,
}: StrokesGainedCardProps) {
  const Icon = categoryIcons[category];
  const gradient = categoryColors[category];
  
  const getTrendIcon = () => {
    if (trend > 0.1) return <TrendingUp className="w-4 h-4 text-accent-green" />;
    if (trend < -0.1) return <TrendingDown className="w-4 h-4 text-accent-red" />;
    return <Minus className="w-4 h-4 text-foreground-muted" />;
  };

  return (
    <Card className={cn("relative overflow-hidden", className)}>
      {/* Background gradient accent */}
      <div className={cn(
        "absolute top-0 right-0 w-24 h-24 rounded-full opacity-10 blur-2xl",
        `bg-gradient-to-br ${gradient}`
      )} />
      
      <CardContent className="relative">
        <div className="flex items-start justify-between mb-3">
          <div className={cn(
            "w-10 h-10 rounded-lg flex items-center justify-center",
            `bg-gradient-to-br ${gradient}`
          )}>
            <Icon className="w-5 h-5 text-white" />
          </div>
          
          {showTrend && (
            <div className="flex items-center gap-1 text-sm">
              {getTrendIcon()}
              <span className={cn(
                trend > 0.1 ? "text-accent-green" : 
                trend < -0.1 ? "text-accent-red" : 
                "text-foreground-muted"
              )}>
                {trend >= 0 ? "+" : ""}{trend.toFixed(2)}
              </span>
            </div>
          )}
        </div>
        
        <div className="space-y-1">
          <p className="text-sm font-medium text-foreground-muted">{label}</p>
          <div className="flex items-baseline gap-2">
            <span className={cn(
              "text-3xl font-bold tabular-nums animate-count",
              getSGColor(value)
            )}>
              {formatSG(value)}
            </span>
            <span className={cn(
              "text-xs px-2 py-0.5 rounded-full",
              getSGBgColor(value),
              getSGColor(value)
            )}>
              {value >= 0 ? "Gaining" : "Losing"}
            </span>
          </div>
          {description && (
            <p className="text-xs text-foreground-muted mt-2">{description}</p>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

