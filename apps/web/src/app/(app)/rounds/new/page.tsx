"use client";

import { useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { Card, CardHeader, CardTitle, CardContent, Button, Input, Select } from "@/components/ui";
import { cn, getScoreColor } from "@/lib/utils";
import { calculateRoundStrokesGained } from "@/lib/strokes-gained";
import { HoleEntryData, DEFAULT_COURSE_PARS, CLUBS, createDefaultHoleData, SCORING_FORMATS, ScoringFormat, calculateStablefordPoints } from "@/types/golf";
import { createClient } from "@/lib/supabase/client";
import { CourseSearch } from "@/components/course-search";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  ChevronLeft,
  ChevronRight,
  Flag,
  Target,
  CircleDot,
  Loader2,
} from "lucide-react";

type Step = "course" | "holes" | "review";

export default function NewRoundPage() {
  const router = useRouter();
  const supabase = createClient();
  const [step, setStep] = useState<Step>("course");
  const [currentHole, setCurrentHole] = useState(1);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  
  // Course info
  const [courseName, setCourseName] = useState("");
  const [courseRating, setCourseRating] = useState("");
  const [slopeRating, setSlopeRating] = useState("");
  const [playedAt, setPlayedAt] = useState(new Date().toISOString().split("T")[0]);
  const [scoringFormat, setScoringFormat] = useState<ScoringFormat>("stroke");
  
  // Hole data - initialize with default pars
  const [holes, setHoles] = useState<HoleEntryData[]>(
    DEFAULT_COURSE_PARS.map((par, i) => createDefaultHoleData(i + 1, par))
  );

  const updateHole = useCallback((holeNumber: number, data: Partial<HoleEntryData>) => {
    setHoles((prev) =>
      prev.map((h) =>
        h.hole_number === holeNumber ? { ...h, ...data } : h
      )
    );
  }, []);

  const currentHoleData = holes[currentHole - 1];

  // Calculate totals for review
  const calculateTotals = () => {
    const totalScore = holes.reduce((sum, h) => sum + h.score, 0);
    const totalPar = holes.reduce((sum, h) => sum + h.par, 0);
    const totalPutts = holes.reduce((sum, h) => sum + h.putts, 0);
    const fairwaysHit = holes.filter((h) => h.par >= 4 && h.fairway_hit).length;
    const fairwaysTotal = holes.filter((h) => h.par >= 4).length;
    const girCount = holes.filter((h) => h.gir).length;
    const penalties = holes.reduce((sum, h) => sum + h.penalties, 0);
    
    return {
      totalScore,
      totalPar,
      totalPutts,
      fairwaysHit,
      fairwaysTotal,
      girCount,
      penalties,
      scoreToPar: totalScore - totalPar,
    };
  };

  const handleSubmit = async () => {
    setIsSaving(true);
    setSaveError(null);
    
    try {
      // Get current user
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      if (userError || !user) {
        throw new Error("You must be logged in to save a round");
      }

      // Calculate strokes gained
      const sg = calculateRoundStrokesGained(holes);
      const totals = calculateTotals();

      // Insert round
      const { data: round, error: roundError } = await supabase
        .from("rounds")
        .insert({
          user_id: user.id,
          course_name: courseName,
          course_rating: courseRating ? parseFloat(courseRating) : null,
          slope_rating: slopeRating ? parseInt(slopeRating) : null,
          played_at: playedAt,
          total_score: totals.totalScore,
          total_putts: totals.totalPutts,
          fairways_hit: totals.fairwaysHit,
          fairways_total: totals.fairwaysTotal,
          gir: totals.girCount,
          penalties: totals.penalties,
          sg_total: sg.sg_total,
          sg_off_tee: sg.sg_off_tee,
          sg_approach: sg.sg_approach,
          sg_around_green: sg.sg_around_green,
          sg_putting: sg.sg_putting,
          scoring_format: scoringFormat,
        })
        .select()
        .single();

      if (roundError) {
        throw new Error(`Failed to save round: ${roundError.message}`);
      }

      // Insert hole scores
      const holeScores = holes.map((hole) => ({
        round_id: round.id,
        hole_number: hole.hole_number,
        par: hole.par,
        score: hole.score,
        putts: hole.putts,
        fairway_hit: hole.par >= 4 ? hole.fairway_hit : null,
        gir: hole.gir,
        penalties: hole.penalties,
        approach_distance: hole.approach_distance,
        first_putt_distance: hole.first_putt_distance,
        stableford_points: scoringFormat === 'stableford' ? calculateStablefordPoints(hole.score, hole.par) : 0,
      }));

      const { error: holesError } = await supabase
        .from("hole_scores")
        .insert(holeScores);

      if (holesError) {
        // Try to clean up the round if hole scores fail
        await supabase.from("rounds").delete().eq("id", round.id);
        throw new Error(`Failed to save hole scores: ${holesError.message}`);
      }

      // Success! Redirect to the round detail page
      router.push(`/rounds/${round.id}`);
    } catch (error) {
      console.error("Save error:", error);
      setSaveError(error instanceof Error ? error.message : "An unexpected error occurred");
    } finally {
      setIsSaving(false);
    }
  };

  const renderCourseStep = () => (
    <div className="max-w-xl mx-auto space-y-6 animate-fade-in">
      <div className="text-center mb-8">
        <h2 className="text-2xl font-bold text-foreground">Course Information</h2>
        <p className="text-foreground-muted mt-1">Search for a course or enter details manually</p>
      </div>

      <div>
        <label className="block text-sm font-medium text-foreground-muted mb-2">Course Name</label>
        <CourseSearch
          value={courseName}
          onChange={setCourseName}
          onSelect={(course) => {
            setCourseName(course.name);
            if (course.course_rating) setCourseRating(course.course_rating.toString());
            if (course.slope_rating) setSlopeRating(course.slope_rating.toString());
          }}
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Course Rating"
          type="number"
          step="0.1"
          placeholder="72.0"
          value={courseRating}
          onChange={(e) => setCourseRating(e.target.value)}
        />
        <Input
          label="Slope Rating"
          type="number"
          placeholder="130"
          value={slopeRating}
          onChange={(e) => setSlopeRating(e.target.value)}
        />
      </div>

      <Input
        label="Date Played"
        type="date"
        value={playedAt}
        onChange={(e) => setPlayedAt(e.target.value)}
      />

      <div>
        <label className="block text-sm font-medium text-foreground-muted mb-2">Scoring Format</label>
        <div className="grid grid-cols-2 gap-3">
          {SCORING_FORMATS.slice(0, 4).map((format) => (
            <button
              key={format.value}
              type="button"
              onClick={() => setScoringFormat(format.value)}
              className={cn(
                "p-3 rounded-lg border text-left transition-all",
                scoringFormat === format.value
                  ? "border-accent-green bg-accent-green/10"
                  : "border-card-border hover:border-foreground-muted"
              )}
            >
              <div className="font-medium text-sm">{format.label}</div>
              <div className="text-xs text-foreground-muted">{format.description}</div>
            </button>
          ))}
        </div>
      </div>

      <div className="pt-4">
        <Button
          onClick={() => setStep("holes")}
          disabled={!courseName}
          className="w-full"
          size="lg"
        >
          Continue to Scorecard
          <ArrowRight className="w-5 h-5 ml-2" />
        </Button>
      </div>
    </div>
  );

  const renderHolesStep = () => (
    <div className="max-w-2xl mx-auto animate-fade-in">
      {/* Hole Navigation */}
      <div className="flex items-center justify-between mb-6">
        <Button
          variant="ghost"
          onClick={() => setCurrentHole(Math.max(1, currentHole - 1))}
          disabled={currentHole === 1}
        >
          <ChevronLeft className="w-5 h-5" />
          Prev
        </Button>
        
        <div className="text-center">
          <h2 className="text-2xl font-bold text-foreground">Hole {currentHole}</h2>
          <p className="text-foreground-muted">Par {currentHoleData.par}</p>
        </div>
        
        <Button
          variant="ghost"
          onClick={() => setCurrentHole(Math.min(18, currentHole + 1))}
          disabled={currentHole === 18}
        >
          Next
          <ChevronRight className="w-5 h-5" />
        </Button>
      </div>

      {/* Hole Progress */}
      <div className="flex gap-1 mb-8 overflow-x-auto pb-2">
        {holes.map((hole) => (
          <button
            key={hole.hole_number}
            onClick={() => setCurrentHole(hole.hole_number)}
            className={cn(
              "w-8 h-8 rounded-lg text-sm font-medium transition-colors flex-shrink-0",
              currentHole === hole.hole_number
                ? "bg-accent-green text-white"
                : hole.score > 0
                ? "bg-background-tertiary text-foreground"
                : "bg-background-secondary text-foreground-muted"
            )}
          >
            {hole.hole_number}
          </button>
        ))}
      </div>

      {/* Score Entry */}
      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            {/* Par Selection */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Par</label>
              <div className="flex gap-2">
                {[3, 4, 5].map((par) => (
                  <button
                    key={par}
                    onClick={() => updateHole(currentHole, { par })}
                    className={cn(
                      "flex-1 py-2 rounded-lg font-medium transition-colors",
                      currentHoleData.par === par
                        ? "bg-accent-green text-white"
                        : "bg-background-secondary text-foreground-muted hover:bg-background-tertiary"
                    )}
                  >
                    {par}
                  </button>
                ))}
              </div>
            </div>

            {/* Score */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Score</label>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => updateHole(currentHole, { score: Math.max(1, currentHoleData.score - 1) })}
                  className="w-10 h-10 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors text-lg font-medium"
                >
                  -
                </button>
                <span className={cn(
                  "text-2xl font-bold w-10 text-center",
                  getScoreColor(currentHoleData.score, currentHoleData.par)
                )}>
                  {currentHoleData.score}
                </span>
                <button
                  onClick={() => updateHole(currentHole, { score: currentHoleData.score + 1 })}
                  className="w-10 h-10 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors text-lg font-medium"
                >
                  +
                </button>
              </div>
            </div>

            {/* Putts */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Putts</label>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => updateHole(currentHole, { putts: Math.max(0, currentHoleData.putts - 1) })}
                  className="w-10 h-10 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors text-lg font-medium"
                >
                  -
                </button>
                <span className="text-2xl font-bold w-10 text-center text-foreground">
                  {currentHoleData.putts}
                </span>
                <button
                  onClick={() => updateHole(currentHole, { putts: currentHoleData.putts + 1 })}
                  className="w-10 h-10 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors text-lg font-medium"
                >
                  +
                </button>
              </div>
            </div>

            {/* Penalties */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Penalties</label>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => updateHole(currentHole, { penalties: Math.max(0, currentHoleData.penalties - 1) })}
                  className="w-10 h-10 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors text-lg font-medium"
                >
                  -
                </button>
                <span className="text-2xl font-bold w-10 text-center text-accent-red">
                  {currentHoleData.penalties}
                </span>
                <button
                  onClick={() => updateHole(currentHole, { penalties: currentHoleData.penalties + 1 })}
                  className="w-10 h-10 rounded-lg bg-background-secondary hover:bg-background-tertiary transition-colors text-lg font-medium"
                >
                  +
                </button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Additional Stats */}
      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="grid grid-cols-2 gap-6">
            {/* Fairway Hit (only for par 4s and 5s) */}
            {currentHoleData.par >= 4 && (
              <div>
                <label className="block text-sm font-medium text-foreground-muted mb-2">Fairway Hit</label>
                <div className="flex gap-2">
                  {[
                    { value: true, label: "Yes" },
                    { value: false, label: "No" },
                  ].map((option) => (
                    <button
                      key={String(option.value)}
                      onClick={() => updateHole(currentHole, { fairway_hit: option.value })}
                      className={cn(
                        "flex-1 py-2 rounded-lg font-medium transition-colors",
                        currentHoleData.fairway_hit === option.value
                          ? option.value
                            ? "bg-accent-green text-white"
                            : "bg-accent-red text-white"
                          : "bg-background-secondary text-foreground-muted hover:bg-background-tertiary"
                      )}
                    >
                      {option.label}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* GIR */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Green in Regulation</label>
              <div className="flex gap-2">
                {[
                  { value: true, label: "Yes" },
                  { value: false, label: "No" },
                ].map((option) => (
                  <button
                    key={String(option.value)}
                    onClick={() => updateHole(currentHole, { gir: option.value })}
                    className={cn(
                      "flex-1 py-2 rounded-lg font-medium transition-colors",
                      currentHoleData.gir === option.value
                        ? option.value
                          ? "bg-accent-green text-white"
                          : "bg-accent-red text-white"
                        : "bg-background-secondary text-foreground-muted hover:bg-background-tertiary"
                    )}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Approach Distance */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Approach Distance (yards)</label>
              <Input
                type="number"
                placeholder="150"
                value={currentHoleData.approach_distance || ""}
                onChange={(e) => updateHole(currentHole, { 
                  approach_distance: e.target.value ? parseInt(e.target.value) : null 
                })}
              />
            </div>

            {/* First Putt Distance */}
            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">First Putt Distance (feet)</label>
              <Input
                type="number"
                placeholder="20"
                value={currentHoleData.first_putt_distance || ""}
                onChange={(e) => updateHole(currentHole, { 
                  first_putt_distance: e.target.value ? parseInt(e.target.value) : null 
                })}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Navigation Buttons */}
      <div className="flex gap-4">
        <Button variant="secondary" onClick={() => setStep("course")} className="flex-1">
          <ArrowLeft className="w-5 h-5 mr-2" />
          Back to Course
        </Button>
        <Button onClick={() => setStep("review")} className="flex-1">
          Review Round
          <ArrowRight className="w-5 h-5 ml-2" />
        </Button>
      </div>
    </div>
  );

  const renderReviewStep = () => {
    const totals = calculateTotals();
    const sg = calculateRoundStrokesGained(holes);

    return (
      <div className="max-w-3xl mx-auto animate-fade-in">
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold text-foreground">Review Your Round</h2>
          <p className="text-foreground-muted mt-1">{courseName} - {playedAt}</p>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Score</p>
              <p className={cn("text-3xl font-bold", getScoreColor(totals.totalScore, totals.totalPar))}>
                {totals.totalScore}
              </p>
              <p className="text-xs text-foreground-muted">
                {totals.scoreToPar >= 0 ? "+" : ""}{totals.scoreToPar} to par
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Total Putts</p>
              <p className="text-3xl font-bold text-foreground">{totals.totalPutts}</p>
              <p className="text-xs text-foreground-muted">{(totals.totalPutts / 18).toFixed(1)} per hole</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">Fairways</p>
              <p className="text-3xl font-bold text-foreground">
                {totals.fairwaysHit}/{totals.fairwaysTotal}
              </p>
              <p className="text-xs text-foreground-muted">
                {((totals.fairwaysHit / totals.fairwaysTotal) * 100).toFixed(0)}%
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4 text-center">
              <p className="text-sm text-foreground-muted mb-1">GIR</p>
              <p className="text-3xl font-bold text-foreground">{totals.girCount}/18</p>
              <p className="text-xs text-foreground-muted">
                {((totals.girCount / 18) * 100).toFixed(0)}%
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Strokes Gained Preview */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Target className="w-5 h-5 text-accent-green" />
              Strokes Gained Analysis
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
              <div className="text-center p-3 rounded-lg bg-background-secondary">
                <p className="text-xs text-foreground-muted mb-1">Total</p>
                <p className={cn("text-xl font-bold", sg.sg_total >= 0 ? "text-accent-green" : "text-accent-red")}>
                  {sg.sg_total >= 0 ? "+" : ""}{sg.sg_total.toFixed(2)}
                </p>
              </div>
              <div className="text-center p-3 rounded-lg bg-background-secondary">
                <p className="text-xs text-foreground-muted mb-1">Off Tee</p>
                <p className={cn("text-xl font-bold", sg.sg_off_tee >= 0 ? "text-accent-green" : "text-accent-red")}>
                  {sg.sg_off_tee >= 0 ? "+" : ""}{sg.sg_off_tee.toFixed(2)}
                </p>
              </div>
              <div className="text-center p-3 rounded-lg bg-background-secondary">
                <p className="text-xs text-foreground-muted mb-1">Approach</p>
                <p className={cn("text-xl font-bold", sg.sg_approach >= 0 ? "text-accent-green" : "text-accent-red")}>
                  {sg.sg_approach >= 0 ? "+" : ""}{sg.sg_approach.toFixed(2)}
                </p>
              </div>
              <div className="text-center p-3 rounded-lg bg-background-secondary">
                <p className="text-xs text-foreground-muted mb-1">Around Green</p>
                <p className={cn("text-xl font-bold", sg.sg_around_green >= 0 ? "text-accent-green" : "text-accent-red")}>
                  {sg.sg_around_green >= 0 ? "+" : ""}{sg.sg_around_green.toFixed(2)}
                </p>
              </div>
              <div className="text-center p-3 rounded-lg bg-background-secondary">
                <p className="text-xs text-foreground-muted mb-1">Putting</p>
                <p className={cn("text-xl font-bold", sg.sg_putting >= 0 ? "text-accent-green" : "text-accent-red")}>
                  {sg.sg_putting >= 0 ? "+" : ""}{sg.sg_putting.toFixed(2)}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Scorecard */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle>Scorecard</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-card-border">
                    <th className="py-2 px-2 text-left text-foreground-muted font-medium">Hole</th>
                    {holes.slice(0, 9).map((h) => (
                      <th key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted font-medium">
                        {h.hole_number}
                      </th>
                    ))}
                    <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-tertiary">Out</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-b border-card-border">
                    <td className="py-2 px-2 text-foreground-muted">Par</td>
                    {holes.slice(0, 9).map((h) => (
                      <td key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted">
                        {h.par}
                      </td>
                    ))}
                    <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                      {holes.slice(0, 9).reduce((sum, h) => sum + h.par, 0)}
                    </td>
                  </tr>
                  <tr>
                    <td className="py-2 px-2 text-foreground font-medium">Score</td>
                    {holes.slice(0, 9).map((h) => (
                      <td key={h.hole_number} className={cn(
                        "py-2 px-2 text-center font-bold",
                        getScoreColor(h.score, h.par)
                      )}>
                        {h.score}
                      </td>
                    ))}
                    <td className="py-2 px-2 text-center font-bold text-foreground bg-background-tertiary">
                      {holes.slice(0, 9).reduce((sum, h) => sum + h.score, 0)}
                    </td>
                  </tr>
                </tbody>
              </table>

              <table className="w-full text-sm mt-4">
                <thead>
                  <tr className="border-b border-card-border">
                    <th className="py-2 px-2 text-left text-foreground-muted font-medium">Hole</th>
                    {holes.slice(9, 18).map((h) => (
                      <th key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted font-medium">
                        {h.hole_number}
                      </th>
                    ))}
                    <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-tertiary">In</th>
                    <th className="py-2 px-2 text-center text-foreground-muted font-medium bg-background-secondary">Tot</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-b border-card-border">
                    <td className="py-2 px-2 text-foreground-muted">Par</td>
                    {holes.slice(9, 18).map((h) => (
                      <td key={h.hole_number} className="py-2 px-2 text-center text-foreground-muted">
                        {h.par}
                      </td>
                    ))}
                    <td className="py-2 px-2 text-center text-foreground-muted bg-background-tertiary">
                      {holes.slice(9, 18).reduce((sum, h) => sum + h.par, 0)}
                    </td>
                    <td className="py-2 px-2 text-center text-foreground-muted bg-background-secondary">
                      {totals.totalPar}
                    </td>
                  </tr>
                  <tr>
                    <td className="py-2 px-2 text-foreground font-medium">Score</td>
                    {holes.slice(9, 18).map((h) => (
                      <td key={h.hole_number} className={cn(
                        "py-2 px-2 text-center font-bold",
                        getScoreColor(h.score, h.par)
                      )}>
                        {h.score}
                      </td>
                    ))}
                    <td className="py-2 px-2 text-center font-bold text-foreground bg-background-tertiary">
                      {holes.slice(9, 18).reduce((sum, h) => sum + h.score, 0)}
                    </td>
                    <td className={cn(
                      "py-2 px-2 text-center font-bold bg-background-secondary",
                      getScoreColor(totals.totalScore, totals.totalPar)
                    )}>
                      {totals.totalScore}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        {/* Error Message */}
        {saveError && (
          <div className="mb-4 p-4 rounded-lg bg-accent-red/10 border border-accent-red/20 text-accent-red">
            {saveError}
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex gap-4">
          <Button variant="secondary" onClick={() => setStep("holes")} className="flex-1" disabled={isSaving}>
            <ArrowLeft className="w-5 h-5 mr-2" />
            Edit Scores
          </Button>
          <Button onClick={handleSubmit} className="flex-1" disabled={isSaving}>
            {isSaving ? (
              <>
                <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                Saving...
              </>
            ) : (
              <>
                <Check className="w-5 h-5 mr-2" />
                Save Round
              </>
            )}
          </Button>
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen">
      {/* Step Indicator */}
      <div className="max-w-xl mx-auto mb-8">
        <div className="flex items-center justify-between">
          {[
            { key: "course", label: "Course", icon: Flag },
            { key: "holes", label: "Scorecard", icon: Target },
            { key: "review", label: "Review", icon: Check },
          ].map((s, i) => {
            const Icon = s.icon;
            const isActive = step === s.key;
            const isPast = 
              (step === "holes" && s.key === "course") ||
              (step === "review" && (s.key === "course" || s.key === "holes"));

            return (
              <div key={s.key} className="flex items-center">
                <div className={cn(
                  "flex items-center gap-2 px-4 py-2 rounded-full transition-colors",
                  isActive
                    ? "bg-accent-green text-white"
                    : isPast
                    ? "bg-accent-green/20 text-accent-green"
                    : "bg-background-secondary text-foreground-muted"
                )}>
                  <Icon className="w-4 h-4" />
                  <span className="text-sm font-medium hidden sm:inline">{s.label}</span>
                </div>
                {i < 2 && (
                  <div className={cn(
                    "w-8 md:w-16 h-0.5 mx-2",
                    isPast || isActive ? "bg-accent-green" : "bg-background-tertiary"
                  )} />
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Step Content */}
      {step === "course" && renderCourseStep()}
      {step === "holes" && renderHolesStep()}
      {step === "review" && renderReviewStep()}
    </div>
  );
}

