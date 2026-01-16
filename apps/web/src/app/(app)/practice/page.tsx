"use client";

import { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent, Button, Input, Select } from "@/components/ui";
import { createClient } from "@/lib/supabase/client";
import { cn, formatDate } from "@/lib/utils";
import {
  Plus,
  Calendar,
  Clock,
  Target,
  Loader2,
  Trash2,
  Star,
  Dumbbell,
  CircleDot,
} from "lucide-react";

interface PracticeSession {
  id: string;
  session_date: string;
  duration_minutes: number | null;
  driving_range: number;
  chipping: number;
  pitching: number;
  bunker: number;
  putting: number;
  focus_area: string | null;
  balls_hit: number | null;
  notes: string | null;
  rating: number | null;
}

const FOCUS_AREAS = [
  { value: "off_tee", label: "Off the Tee" },
  { value: "approach", label: "Approach Shots" },
  { value: "around_green", label: "Around the Green" },
  { value: "putting", label: "Putting" },
  { value: "general", label: "General Practice" },
];

export default function PracticePage() {
  const supabase = createClient();
  const [sessions, setSessions] = useState<PracticeSession[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  // Form state
  const [sessionDate, setSessionDate] = useState(new Date().toISOString().split("T")[0]);
  const [duration, setDuration] = useState("");
  const [drivingRange, setDrivingRange] = useState("0");
  const [chipping, setChipping] = useState("0");
  const [pitching, setPitching] = useState("0");
  const [bunker, setBunker] = useState("0");
  const [putting, setPutting] = useState("0");
  const [focusArea, setFocusArea] = useState("");
  const [ballsHit, setBallsHit] = useState("");
  const [notes, setNotes] = useState("");
  const [rating, setRating] = useState(0);

  useEffect(() => {
    loadSessions();
  }, []);

  async function loadSessions() {
    setIsLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase
        .from("practice_sessions")
        .select("*")
        .eq("user_id", user.id)
        .order("session_date", { ascending: false });

      if (error) throw error;
      setSessions(data || []);
    } catch (err) {
      console.error("Error loading sessions:", err);
    } finally {
      setIsLoading(false);
    }
  }

  const resetForm = () => {
    setSessionDate(new Date().toISOString().split("T")[0]);
    setDuration("");
    setDrivingRange("0");
    setChipping("0");
    setPitching("0");
    setBunker("0");
    setPutting("0");
    setFocusArea("");
    setBallsHit("");
    setNotes("");
    setRating(0);
  };

  const handleSubmit = async () => {
    setIsSaving(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not logged in");

      const { error } = await supabase.from("practice_sessions").insert({
        user_id: user.id,
        session_date: sessionDate,
        duration_minutes: duration ? parseInt(duration) : null,
        driving_range: parseInt(drivingRange) || 0,
        chipping: parseInt(chipping) || 0,
        pitching: parseInt(pitching) || 0,
        bunker: parseInt(bunker) || 0,
        putting: parseInt(putting) || 0,
        focus_area: focusArea || null,
        balls_hit: ballsHit ? parseInt(ballsHit) : null,
        notes: notes || null,
        rating: rating || null,
      });

      if (error) throw error;
      
      resetForm();
      setShowForm(false);
      loadSessions();
    } catch (err) {
      console.error("Error saving session:", err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Delete this practice session?")) return;
    
    try {
      const { error } = await supabase.from("practice_sessions").delete().eq("id", id);
      if (error) throw error;
      setSessions(sessions.filter(s => s.id !== id));
    } catch (err) {
      console.error("Error deleting session:", err);
    }
  };

  // Calculate stats
  const totalSessions = sessions.length;
  const totalTime = sessions.reduce((sum, s) => sum + (s.duration_minutes || 0), 0);
  const totalBalls = sessions.reduce((sum, s) => sum + (s.balls_hit || 0), 0);
  const avgRating = sessions.filter(s => s.rating).length > 0
    ? sessions.reduce((sum, s) => sum + (s.rating || 0), 0) / sessions.filter(s => s.rating).length
    : 0;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 animate-spin text-accent-green" />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Practice Log</h1>
          <p className="text-foreground-muted mt-1">
            Track your practice sessions and improvement
          </p>
        </div>
        <Button onClick={() => setShowForm(!showForm)}>
          <Plus className="w-5 h-5 mr-2" />
          Log Practice
        </Button>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <Calendar className="w-5 h-5 text-accent-blue mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">{totalSessions}</p>
            <p className="text-xs text-foreground-muted">Total Sessions</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <Clock className="w-5 h-5 text-accent-green mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">{Math.round(totalTime / 60)}h {totalTime % 60}m</p>
            <p className="text-xs text-foreground-muted">Total Time</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <CircleDot className="w-5 h-5 text-accent-purple mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">{totalBalls.toLocaleString()}</p>
            <p className="text-xs text-foreground-muted">Balls Hit</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <Star className="w-5 h-5 text-accent-amber mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">{avgRating.toFixed(1)}</p>
            <p className="text-xs text-foreground-muted">Avg Rating</p>
          </CardContent>
        </Card>
      </div>

      {/* New Session Form */}
      {showForm && (
        <Card>
          <CardHeader>
            <CardTitle>Log Practice Session</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Input
                label="Date"
                type="date"
                value={sessionDate}
                onChange={(e) => setSessionDate(e.target.value)}
              />
              <Input
                label="Duration (minutes)"
                type="number"
                placeholder="60"
                value={duration}
                onChange={(e) => setDuration(e.target.value)}
              />
              <Input
                label="Balls Hit"
                type="number"
                placeholder="100"
                value={ballsHit}
                onChange={(e) => setBallsHit(e.target.value)}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Time Spent (minutes)</label>
              <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                <Input
                  label="Driving Range"
                  type="number"
                  value={drivingRange}
                  onChange={(e) => setDrivingRange(e.target.value)}
                />
                <Input
                  label="Chipping"
                  type="number"
                  value={chipping}
                  onChange={(e) => setChipping(e.target.value)}
                />
                <Input
                  label="Pitching"
                  type="number"
                  value={pitching}
                  onChange={(e) => setPitching(e.target.value)}
                />
                <Input
                  label="Bunker"
                  type="number"
                  value={bunker}
                  onChange={(e) => setBunker(e.target.value)}
                />
                <Input
                  label="Putting"
                  type="number"
                  value={putting}
                  onChange={(e) => setPutting(e.target.value)}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-foreground-muted mb-2">Focus Area</label>
                <select
                  value={focusArea}
                  onChange={(e) => setFocusArea(e.target.value)}
                  className="w-full px-4 py-2 rounded-lg bg-background-secondary border border-card-border text-foreground focus:outline-none focus:ring-2 focus:ring-accent-green"
                >
                  <option value="">Select focus area...</option>
                  {FOCUS_AREAS.map((area) => (
                    <option key={area.value} value={area.value}>{area.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-foreground-muted mb-2">Session Rating</label>
                <div className="flex gap-2">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      key={star}
                      onClick={() => setRating(star)}
                      className={cn(
                        "w-10 h-10 rounded-lg flex items-center justify-center transition-colors",
                        star <= rating
                          ? "bg-accent-amber text-white"
                          : "bg-background-secondary text-foreground-muted hover:bg-background-tertiary"
                      )}
                    >
                      <Star className={cn("w-5 h-5", star <= rating && "fill-current")} />
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Notes</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="What did you work on? Any breakthroughs?"
                className="w-full px-4 py-2 rounded-lg bg-background-secondary border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green resize-none"
                rows={3}
              />
            </div>

            <div className="flex gap-4">
              <Button variant="secondary" onClick={() => { resetForm(); setShowForm(false); }} className="flex-1">
                Cancel
              </Button>
              <Button onClick={handleSubmit} disabled={isSaving} className="flex-1">
                {isSaving ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Plus className="w-4 h-4 mr-2" />}
                Save Session
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Sessions List */}
      <div className="space-y-4">
        {sessions.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <Dumbbell className="w-12 h-12 text-foreground-muted mx-auto mb-4" />
              <h3 className="text-lg font-medium text-foreground mb-2">No practice sessions logged</h3>
              <p className="text-foreground-muted mb-4">
                Start logging your practice to track improvement
              </p>
              <Button onClick={() => setShowForm(true)}>
                <Plus className="w-4 h-4 mr-2" />
                Log Your First Session
              </Button>
            </CardContent>
          </Card>
        ) : (
          sessions.map((session) => (
            <Card key={session.id} hover>
              <CardContent className="p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <span className="text-foreground font-medium">{formatDate(session.session_date)}</span>
                      {session.duration_minutes && (
                        <span className="text-sm text-foreground-muted flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          {session.duration_minutes} min
                        </span>
                      )}
                      {session.rating && (
                        <div className="flex items-center gap-1">
                          {Array.from({ length: session.rating }).map((_, i) => (
                            <Star key={i} className="w-4 h-4 text-accent-amber fill-current" />
                          ))}
                        </div>
                      )}
                    </div>
                    
                    <div className="flex flex-wrap gap-2 mb-2">
                      {session.driving_range > 0 && (
                        <span className="px-2 py-1 text-xs rounded bg-accent-blue/10 text-accent-blue">
                          Range: {session.driving_range}m
                        </span>
                      )}
                      {session.putting > 0 && (
                        <span className="px-2 py-1 text-xs rounded bg-accent-green/10 text-accent-green">
                          Putting: {session.putting}m
                        </span>
                      )}
                      {session.chipping > 0 && (
                        <span className="px-2 py-1 text-xs rounded bg-accent-purple/10 text-accent-purple">
                          Chipping: {session.chipping}m
                        </span>
                      )}
                      {session.pitching > 0 && (
                        <span className="px-2 py-1 text-xs rounded bg-accent-amber/10 text-accent-amber">
                          Pitching: {session.pitching}m
                        </span>
                      )}
                      {session.bunker > 0 && (
                        <span className="px-2 py-1 text-xs rounded bg-accent-red/10 text-accent-red">
                          Bunker: {session.bunker}m
                        </span>
                      )}
                    </div>
                    
                    {session.focus_area && (
                      <p className="text-sm text-foreground-muted">
                        Focus: {FOCUS_AREAS.find(f => f.value === session.focus_area)?.label}
                      </p>
                    )}
                    
                    {session.notes && (
                      <p className="text-sm text-foreground-muted mt-2">{session.notes}</p>
                    )}
                  </div>
                  
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDelete(session.id)}
                    className="text-accent-red hover:text-accent-red"
                  >
                    <Trash2 className="w-4 h-4" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}

