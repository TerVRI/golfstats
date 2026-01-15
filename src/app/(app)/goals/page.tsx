"use client";

import { useEffect, useState } from "react";
import { Card, CardHeader, CardTitle, CardContent, Button, Input } from "@/components/ui";
import { createClient } from "@/lib/supabase/client";
import { cn, formatDate } from "@/lib/utils";
import {
  Plus,
  Target,
  Trophy,
  Loader2,
  Trash2,
  Check,
  Calendar,
  TrendingUp,
  Flag,
  Award,
} from "lucide-react";

interface Goal {
  id: string;
  title: string;
  description: string | null;
  category: string;
  target_value: number | null;
  current_value: number | null;
  target_date: string | null;
  status: string;
  completed_at: string | null;
  created_at: string;
}

const CATEGORIES = [
  { value: "handicap", label: "Handicap", icon: Award },
  { value: "score", label: "Score", icon: Target },
  { value: "strokes_gained", label: "Strokes Gained", icon: TrendingUp },
  { value: "putting", label: "Putting", icon: Flag },
  { value: "driving", label: "Driving", icon: Flag },
  { value: "approach", label: "Approach", icon: Target },
  { value: "practice", label: "Practice", icon: Calendar },
  { value: "rounds", label: "Rounds Played", icon: Trophy },
  { value: "other", label: "Other", icon: Target },
];

export default function GoalsPage() {
  const supabase = createClient();
  const [goals, setGoals] = useState<Goal[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  // Form state
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [targetValue, setTargetValue] = useState("");
  const [targetDate, setTargetDate] = useState("");

  useEffect(() => {
    loadGoals();
  }, []);

  async function loadGoals() {
    setIsLoading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase
        .from("goals")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false });

      if (error) throw error;
      setGoals(data || []);
    } catch (err) {
      console.error("Error loading goals:", err);
    } finally {
      setIsLoading(false);
    }
  }

  const resetForm = () => {
    setTitle("");
    setDescription("");
    setCategory("");
    setTargetValue("");
    setTargetDate("");
  };

  const handleSubmit = async () => {
    if (!title || !category) return;
    setIsSaving(true);
    
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not logged in");

      const { error } = await supabase.from("goals").insert({
        user_id: user.id,
        title,
        description: description || null,
        category,
        target_value: targetValue ? parseFloat(targetValue) : null,
        target_date: targetDate || null,
        status: "active",
      });

      if (error) throw error;
      
      resetForm();
      setShowForm(false);
      loadGoals();
    } catch (err) {
      console.error("Error saving goal:", err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleComplete = async (id: string) => {
    try {
      const { error } = await supabase
        .from("goals")
        .update({ status: "completed", completed_at: new Date().toISOString() })
        .eq("id", id);

      if (error) throw error;
      loadGoals();
    } catch (err) {
      console.error("Error completing goal:", err);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm("Delete this goal?")) return;
    
    try {
      const { error } = await supabase.from("goals").delete().eq("id", id);
      if (error) throw error;
      setGoals(goals.filter(g => g.id !== id));
    } catch (err) {
      console.error("Error deleting goal:", err);
    }
  };

  const activeGoals = goals.filter(g => g.status === "active");
  const completedGoals = goals.filter(g => g.status === "completed");

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
          <h1 className="text-2xl md:text-3xl font-bold text-foreground">Goals</h1>
          <p className="text-foreground-muted mt-1">
            Set and track your golf improvement goals
          </p>
        </div>
        <Button onClick={() => setShowForm(!showForm)}>
          <Plus className="w-5 h-5 mr-2" />
          New Goal
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <Target className="w-5 h-5 text-accent-blue mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">{activeGoals.length}</p>
            <p className="text-xs text-foreground-muted">Active Goals</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <Trophy className="w-5 h-5 text-accent-green mx-auto mb-2" />
            <p className="text-2xl font-bold text-accent-green">{completedGoals.length}</p>
            <p className="text-xs text-foreground-muted">Completed</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <TrendingUp className="w-5 h-5 text-accent-purple mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">
              {goals.length > 0 ? Math.round((completedGoals.length / goals.length) * 100) : 0}%
            </p>
            <p className="text-xs text-foreground-muted">Success Rate</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <Calendar className="w-5 h-5 text-accent-amber mx-auto mb-2" />
            <p className="text-2xl font-bold text-foreground">{goals.length}</p>
            <p className="text-xs text-foreground-muted">Total Goals</p>
          </CardContent>
        </Card>
      </div>

      {/* New Goal Form */}
      {showForm && (
        <Card>
          <CardHeader>
            <CardTitle>Create New Goal</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Input
              label="Goal Title"
              placeholder="e.g., Break 80, Lower handicap to 10"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />

            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Category</label>
              <div className="grid grid-cols-3 md:grid-cols-5 gap-2">
                {CATEGORIES.map((cat) => {
                  const Icon = cat.icon;
                  return (
                    <button
                      key={cat.value}
                      onClick={() => setCategory(cat.value)}
                      className={cn(
                        "p-3 rounded-lg text-sm font-medium transition-colors flex flex-col items-center gap-1",
                        category === cat.value
                          ? "bg-accent-green text-white"
                          : "bg-background-secondary text-foreground-muted hover:bg-background-tertiary"
                      )}
                    >
                      <Icon className="w-4 h-4" />
                      {cat.label}
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input
                label="Target Value (optional)"
                type="number"
                placeholder="e.g., 80, 10, 5"
                value={targetValue}
                onChange={(e) => setTargetValue(e.target.value)}
              />
              <Input
                label="Target Date (optional)"
                type="date"
                value={targetDate}
                onChange={(e) => setTargetDate(e.target.value)}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground-muted mb-2">Description (optional)</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Add more details about your goal..."
                className="w-full px-4 py-2 rounded-lg bg-background-secondary border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green resize-none"
                rows={3}
              />
            </div>

            <div className="flex gap-4">
              <Button variant="secondary" onClick={() => { resetForm(); setShowForm(false); }} className="flex-1">
                Cancel
              </Button>
              <Button onClick={handleSubmit} disabled={isSaving || !title || !category} className="flex-1">
                {isSaving ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Plus className="w-4 h-4 mr-2" />}
                Create Goal
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Active Goals */}
      {activeGoals.length > 0 && (
        <div>
          <h2 className="text-lg font-semibold text-foreground mb-4">Active Goals</h2>
          <div className="space-y-4">
            {activeGoals.map((goal) => {
              const categoryInfo = CATEGORIES.find(c => c.value === goal.category);
              const Icon = categoryInfo?.icon || Target;
              
              return (
                <Card key={goal.id} hover>
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex items-start gap-4">
                        <div className={cn(
                          "w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0",
                          "bg-accent-blue/10"
                        )}>
                          <Icon className="w-5 h-5 text-accent-blue" />
                        </div>
                        <div>
                          <h3 className="font-medium text-foreground">{goal.title}</h3>
                          <p className="text-sm text-foreground-muted">{categoryInfo?.label}</p>
                          {goal.description && (
                            <p className="text-sm text-foreground-muted mt-1">{goal.description}</p>
                          )}
                          <div className="flex gap-4 mt-2 text-xs text-foreground-muted">
                            {goal.target_value && (
                              <span>Target: {goal.target_value}</span>
                            )}
                            {goal.target_date && (
                              <span>Due: {formatDate(goal.target_date)}</span>
                            )}
                            <span>Created: {formatDate(goal.created_at)}</span>
                          </div>
                        </div>
                      </div>
                      
                      <div className="flex gap-2">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleComplete(goal.id)}
                          className="text-accent-green hover:text-accent-green"
                        >
                          <Check className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleDelete(goal.id)}
                          className="text-accent-red hover:text-accent-red"
                        >
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </div>
      )}

      {/* Completed Goals */}
      {completedGoals.length > 0 && (
        <div>
          <h2 className="text-lg font-semibold text-foreground mb-4">Completed Goals</h2>
          <div className="space-y-4">
            {completedGoals.map((goal) => {
              const categoryInfo = CATEGORIES.find(c => c.value === goal.category);
              const Icon = categoryInfo?.icon || Target;
              
              return (
                <Card key={goal.id} className="opacity-75">
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex items-start gap-4">
                        <div className="w-10 h-10 rounded-lg bg-accent-green/10 flex items-center justify-center flex-shrink-0">
                          <Trophy className="w-5 h-5 text-accent-green" />
                        </div>
                        <div>
                          <h3 className="font-medium text-foreground line-through">{goal.title}</h3>
                          <p className="text-sm text-foreground-muted">{categoryInfo?.label}</p>
                          {goal.completed_at && (
                            <p className="text-xs text-accent-green mt-1">
                              Completed: {formatDate(goal.completed_at)}
                            </p>
                          )}
                        </div>
                      </div>
                      
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleDelete(goal.id)}
                        className="text-foreground-muted hover:text-accent-red"
                      >
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </div>
      )}

      {/* Empty State */}
      {goals.length === 0 && !showForm && (
        <Card>
          <CardContent className="py-12 text-center">
            <Target className="w-12 h-12 text-foreground-muted mx-auto mb-4" />
            <h3 className="text-lg font-medium text-foreground mb-2">No goals set</h3>
            <p className="text-foreground-muted mb-4">
              Set goals to track your improvement and stay motivated
            </p>
            <Button onClick={() => setShowForm(true)}>
              <Plus className="w-4 h-4 mr-2" />
              Create Your First Goal
            </Button>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

