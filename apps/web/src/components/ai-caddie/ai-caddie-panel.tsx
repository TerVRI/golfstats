'use client';

import { useState, useEffect } from 'react';
import { cn } from '@/lib/utils';
import { GreenLocation } from '@/lib/gps-tracking';

interface AICaddiePanelProps {
  distance: number;
  greenLocation?: GreenLocation | null;
  elevation?: number;
  wind?: { speed: number; direction: number };
  temperature?: number;
  className?: string;
}

interface ClubRecommendation {
  club: string;
  alternateClub?: string;
  reasoning: string;
  confidence: number;
}

interface PlaysLikeDistance {
  actual: number;
  adjusted: number;
  factors: Array<{ name: string; adjustment: number; description: string }>;
}

interface RiskAssessment {
  level: 'low' | 'medium' | 'high';
  factors: string[];
}

/**
 * AI Caddie Panel for Web
 * Provides club recommendations and course strategy
 */
export function AICaddiePanel({
  distance,
  greenLocation,
  elevation = 0,
  wind,
  temperature = 70,
  className,
}: AICaddiePanelProps) {
  const [recommendation, setRecommendation] = useState<ClubRecommendation | null>(null);
  const [playsLike, setPlaysLike] = useState<PlaysLikeDistance | null>(null);
  const [risk, setRisk] = useState<RiskAssessment | null>(null);
  const [isExpanded, setIsExpanded] = useState(true);

  // Calculate recommendations when distance changes
  useEffect(() => {
    if (distance > 0) {
      const rec = calculateClubRecommendation(distance, { elevation, wind, temperature });
      setRecommendation(rec.club);
      setPlaysLike(rec.playsLike);
      setRisk(rec.risk);
    }
  }, [distance, elevation, wind, temperature]);

  if (!recommendation) {
    return (
      <div className={cn('bg-card rounded-lg border p-4', className)}>
        <div className="flex items-center gap-2 text-muted-foreground">
          <span className="text-xl">🧠</span>
          <span>AI Caddie</span>
        </div>
        <p className="text-sm text-muted-foreground mt-2">
          No distance data available
        </p>
      </div>
    );
  }

  return (
    <div className={cn('bg-card rounded-lg border overflow-hidden', className)}>
      {/* Header */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full p-4 flex items-center justify-between hover:bg-muted/50 transition"
      >
        <div className="flex items-center gap-2">
          <span className="text-xl">🧠</span>
          <span className="font-semibold">AI Caddie</span>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-lg font-bold text-green-500">{recommendation.club}</span>
          <span className="text-muted-foreground">{isExpanded ? '▲' : '▼'}</span>
        </div>
      </button>

      {/* Content */}
      {isExpanded && (
        <div className="px-4 pb-4 space-y-4">
          {/* Main recommendation */}
          <div className="text-center p-4 bg-green-500/10 rounded-lg">
            <div className="text-sm text-muted-foreground">Recommended Club</div>
            <div className="text-3xl font-bold text-green-500 mt-1">{recommendation.club}</div>
            {recommendation.alternateClub && (
              <div className="text-sm text-muted-foreground mt-1">
                or {recommendation.alternateClub}
              </div>
            )}
            <div className="text-sm text-muted-foreground mt-2">
              {recommendation.reasoning}
            </div>
          </div>

          {/* Plays Like Distance */}
          {playsLike && playsLike.adjusted !== playsLike.actual && (
            <div className="p-3 bg-muted rounded-lg">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium">Plays Like</span>
                <span className="font-bold">
                  {playsLike.adjusted}y
                  <span className={cn(
                    'text-sm ml-1',
                    playsLike.adjusted > playsLike.actual ? 'text-red-500' : 'text-green-500'
                  )}>
                    ({playsLike.adjusted > playsLike.actual ? '+' : ''}{playsLike.adjusted - playsLike.actual})
                  </span>
                </span>
              </div>
              
              {/* Factors */}
              <div className="space-y-1">
                {playsLike.factors.map((factor, i) => (
                  <div key={i} className="flex justify-between text-xs">
                    <span className="text-muted-foreground">{factor.name}</span>
                    <span className={factor.adjustment > 0 ? 'text-red-500' : 'text-green-500'}>
                      {factor.adjustment > 0 ? '+' : ''}{factor.adjustment}y
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Risk Assessment */}
          {risk && (
            <div className={cn(
              'p-3 rounded-lg',
              risk.level === 'low' && 'bg-green-500/10',
              risk.level === 'medium' && 'bg-yellow-500/10',
              risk.level === 'high' && 'bg-red-500/10'
            )}>
              <div className="flex items-center gap-2 mb-2">
                <span className={cn(
                  'w-2 h-2 rounded-full',
                  risk.level === 'low' && 'bg-green-500',
                  risk.level === 'medium' && 'bg-yellow-500',
                  risk.level === 'high' && 'bg-red-500'
                )} />
                <span className="text-sm font-medium">
                  Risk: {risk.level.charAt(0).toUpperCase() + risk.level.slice(1)}
                </span>
              </div>
              
              {risk.factors.length > 0 && (
                <ul className="text-xs text-muted-foreground space-y-1">
                  {risk.factors.map((factor, i) => (
                    <li key={i}>• {factor}</li>
                  ))}
                </ul>
              )}
            </div>
          )}

          {/* Confidence */}
          <div className="flex items-center justify-between text-xs text-muted-foreground">
            <span>Confidence</span>
            <div className="flex items-center gap-2">
              <div className="w-20 h-2 bg-muted rounded-full overflow-hidden">
                <div
                  className="h-full bg-green-500 rounded-full"
                  style={{ width: `${recommendation.confidence * 100}%` }}
                />
              </div>
              <span>{Math.round(recommendation.confidence * 100)}%</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// Club recommendation calculation
function calculateClubRecommendation(
  distance: number,
  conditions: {
    elevation?: number;
    wind?: { speed: number; direction: number };
    temperature?: number;
  }
): {
  club: ClubRecommendation;
  playsLike: PlaysLikeDistance;
  risk: RiskAssessment;
} {
  const { elevation = 0, wind, temperature = 70 } = conditions;

  // Calculate "plays like" distance
  const factors: PlaysLikeDistance['factors'] = [];
  let adjusted = distance;

  // Elevation adjustment (~1 yard per 3 feet)
  if (Math.abs(elevation) > 5) {
    const elevationAdj = Math.round(elevation / 3);
    adjusted += elevationAdj;
    factors.push({
      name: elevation > 0 ? 'Uphill' : 'Downhill',
      adjustment: elevationAdj,
      description: `${Math.abs(elevation)}ft elevation`,
    });
  }

  // Wind adjustment
  if (wind && wind.speed > 5) {
    // Simplified - into wind adds distance, downwind subtracts
    const windAdj = Math.round(wind.speed * 0.5);
    const isIntoWind = wind.direction > 90 && wind.direction < 270;
    adjusted += isIntoWind ? windAdj : -windAdj;
    factors.push({
      name: isIntoWind ? 'Into Wind' : 'Downwind',
      adjustment: isIntoWind ? windAdj : -windAdj,
      description: `${wind.speed}mph`,
    });
  }

  // Temperature adjustment (~2 yards per 20°F from 70°F)
  const tempDiff = 70 - temperature;
  if (Math.abs(tempDiff) > 15) {
    const tempAdj = Math.round(tempDiff / 10);
    adjusted += tempAdj;
    factors.push({
      name: temperature < 70 ? 'Cold' : 'Warm',
      adjustment: tempAdj,
      description: `${temperature}°F`,
    });
  }

  // Find best club based on adjusted distance
  const clubDistances: Record<string, number> = {
    'Driver': 250,
    '3 Wood': 230,
    '5 Wood': 215,
    '4 Hybrid': 200,
    '5 Iron': 185,
    '6 Iron': 175,
    '7 Iron': 165,
    '8 Iron': 155,
    '9 Iron': 145,
    'PW': 135,
    'GW': 120,
    'SW': 100,
    'LW': 80,
  };

  let bestClub = '7 Iron';
  let bestDiff = Infinity;
  let secondBest: string | undefined;
  let secondBestDiff = Infinity;

  for (const [club, dist] of Object.entries(clubDistances)) {
    const diff = Math.abs(dist - adjusted);
    if (diff < bestDiff) {
      secondBest = bestClub;
      secondBestDiff = bestDiff;
      bestClub = club;
      bestDiff = diff;
    } else if (diff < secondBestDiff) {
      secondBest = club;
      secondBestDiff = diff;
    }
  }

  // Calculate confidence based on how well the club matches
  const confidence = Math.max(0.5, 1 - (bestDiff / 20));

  // Risk assessment
  const riskFactors: string[] = [];
  let riskLevel: RiskAssessment['level'] = 'low';

  if (distance > 200) {
    riskFactors.push('Long approach increases miss probability');
    riskLevel = 'medium';
  }

  if (wind && wind.speed > 15) {
    riskFactors.push('Strong wind affects accuracy');
    riskLevel = 'high';
  }

  if (Math.abs(elevation) > 30) {
    riskFactors.push('Significant elevation change');
    if (riskLevel !== 'high') riskLevel = 'medium';
  }

  return {
    club: {
      club: bestClub,
      alternateClub: secondBest,
      reasoning: factors.length > 0
        ? `Plays ${adjusted}y with adjustments`
        : `Based on ${adjusted} yard distance`,
      confidence,
    },
    playsLike: {
      actual: distance,
      adjusted,
      factors,
    },
    risk: {
      level: riskLevel,
      factors: riskFactors,
    },
  };
}

// Compact version for use in other components
export function AICaddieBadge({ distance }: { distance: number }) {
  const [club, setClub] = useState<string>('--');

  useEffect(() => {
    if (distance > 0) {
      const rec = calculateClubRecommendation(distance, {});
      setClub(rec.club.club);
    }
  }, [distance]);

  return (
    <div className="inline-flex items-center gap-1 px-2 py-1 bg-purple-500/10 text-purple-600 rounded text-xs">
      <span>🧠</span>
      <span className="font-medium">{club}</span>
    </div>
  );
}
