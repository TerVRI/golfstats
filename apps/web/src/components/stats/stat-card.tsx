"use client";

import { cn } from "@/lib/utils";
import { Card, CardContent } from "@/components/ui";
import { LucideIcon } from "lucide-react";

interface StatCardProps {
  label: string;
  value: string | number;
  icon?: LucideIcon;
  subtitle?: string;
  color?: "default" | "green" | "red" | "amber" | "blue";
  className?: string;
}

const colorClasses = {
  default: "text-foreground",
  green: "text-accent-green",
  red: "text-accent-red",
  amber: "text-amber-400",
  blue: "text-accent-blue",
};

const iconBgClasses = {
  default: "bg-background-tertiary",
  green: "bg-accent-green/10",
  red: "bg-accent-red/10",
  amber: "bg-amber-400/10",
  blue: "bg-accent-blue/10",
};

export function StatCard({
  label,
  value,
  icon: Icon,
  subtitle,
  color = "default",
  className,
}: StatCardProps) {
  return (
    <Card className={cn("", className)}>
      <CardContent>
        <div className="flex items-start justify-between">
          <div className="space-y-1">
            <p className="text-sm font-medium text-foreground-muted">{label}</p>
            <p className={cn(
              "text-2xl font-bold tabular-nums animate-count",
              colorClasses[color]
            )}>
              {value}
            </p>
            {subtitle && (
              <p className="text-xs text-foreground-muted">{subtitle}</p>
            )}
          </div>
          
          {Icon && (
            <div className={cn(
              "w-10 h-10 rounded-lg flex items-center justify-center",
              iconBgClasses[color]
            )}>
              <Icon className={cn("w-5 h-5", colorClasses[color])} />
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

