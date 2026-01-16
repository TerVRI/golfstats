"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useUser } from "@/hooks/useUser";
import { ClubData, ClubType } from "@/types/golf";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import {
  Plus,
  Trash2,
  Edit2,
  X,
  Check,
  ChevronDown,
  ChevronUp,
  Target,
} from "lucide-react";

const CLUB_TYPES: { value: ClubType; label: string; icon: string }[] = [
  { value: "driver", label: "Driver", icon: "🏌️" },
  { value: "wood", label: "Fairway Wood", icon: "🌲" },
  { value: "hybrid", label: "Hybrid", icon: "🔀" },
  { value: "iron", label: "Iron", icon: "🔩" },
  { value: "wedge", label: "Wedge", icon: "⛳" },
  { value: "putter", label: "Putter", icon: "🎯" },
];

const POPULAR_BRANDS = [
  "TaylorMade",
  "Callaway",
  "Titleist",
  "Ping",
  "Cobra",
  "Mizuno",
  "Srixon",
  "Cleveland",
  "Wilson",
  "Bridgestone",
];

interface ClubFormData {
  name: string;
  brand: string;
  model: string;
  club_type: ClubType;
  loft: string;
  shaft: string;
  shaft_material: "graphite" | "steel" | "";
  avg_distance: string;
}

const defaultFormData: ClubFormData = {
  name: "",
  brand: "",
  model: "",
  club_type: "iron",
  loft: "",
  shaft: "",
  shaft_material: "",
  avg_distance: "",
};

export default function BagPage() {
  const { user } = useUser();
  const supabase = createClient();

  const [clubs, setClubs] = useState<ClubData[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingClub, setEditingClub] = useState<ClubData | null>(null);
  const [formData, setFormData] = useState<ClubFormData>(defaultFormData);
  const [saving, setSaving] = useState(false);
  const [expandedType, setExpandedType] = useState<ClubType | null>(null);

  useEffect(() => {
    if (user) {
      fetchClubs();
    }
  }, [user]);

  const fetchClubs = async () => {
    if (!user) return;

    const { data, error } = await supabase
      .from("clubs")
      .select("*")
      .eq("user_id", user.id)
      .order("display_order", { ascending: true });

    if (error) {
      console.error("Error fetching clubs:", error);
    } else {
      setClubs(data || []);
    }
    setLoading(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setSaving(true);

    const clubData = {
      user_id: user.id,
      name: formData.name,
      brand: formData.brand || null,
      model: formData.model || null,
      club_type: formData.club_type,
      loft: formData.loft ? parseFloat(formData.loft) : null,
      shaft: formData.shaft || null,
      shaft_material: formData.shaft_material || null,
      avg_distance: formData.avg_distance ? parseInt(formData.avg_distance) : null,
      in_bag: true,
      display_order: clubs.length,
    };

    if (editingClub) {
      const { error } = await supabase
        .from("clubs")
        .update(clubData)
        .eq("id", editingClub.id);

      if (error) {
        console.error("Error updating club:", error);
      }
    } else {
      const { error } = await supabase.from("clubs").insert([clubData]);

      if (error) {
        console.error("Error adding club:", error);
      }
    }

    setSaving(false);
    setShowForm(false);
    setEditingClub(null);
    setFormData(defaultFormData);
    fetchClubs();
  };

  const handleEdit = (club: ClubData) => {
    setEditingClub(club);
    setFormData({
      name: club.name,
      brand: club.brand || "",
      model: club.model || "",
      club_type: club.club_type,
      loft: club.loft?.toString() || "",
      shaft: club.shaft || "",
      shaft_material: club.shaft_material || "",
      avg_distance: club.avg_distance?.toString() || "",
    });
    setShowForm(true);
  };

  const handleDelete = async (clubId: string) => {
    if (!confirm("Remove this club from your bag?")) return;

    const { error } = await supabase.from("clubs").delete().eq("id", clubId);

    if (error) {
      console.error("Error deleting club:", error);
    } else {
      fetchClubs();
    }
  };

  const toggleInBag = async (club: ClubData) => {
    const { error } = await supabase
      .from("clubs")
      .update({ in_bag: !club.in_bag })
      .eq("id", club.id);

    if (error) {
      console.error("Error toggling in_bag:", error);
    } else {
      fetchClubs();
    }
  };

  const clubsByType = CLUB_TYPES.map((type) => ({
    ...type,
    clubs: clubs.filter((c) => c.club_type === type.value && c.in_bag),
  }));

  const clubsNotInBag = clubs.filter((c) => !c.in_bag);
  const totalClubs = clubs.filter((c) => c.in_bag).length;

  if (loading) {
    return (
      <div className="p-6 space-y-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-background-tertiary rounded w-48" />
          <div className="h-64 bg-background-tertiary rounded" />
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold">My Bag</h1>
          <p className="text-foreground-muted">
            {totalClubs} club{totalClubs !== 1 ? "s" : ""} in bag
            {totalClubs > 14 && (
              <span className="text-accent-red ml-2">
                (USGA limit is 14)
              </span>
            )}
          </p>
        </div>
        <Button
          onClick={() => {
            setShowForm(true);
            setEditingClub(null);
            setFormData(defaultFormData);
          }}
        >
          <Plus className="w-4 h-4 mr-2" />
          Add Club
        </Button>
      </div>

      {/* Add/Edit Form Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle>
                {editingClub ? "Edit Club" : "Add New Club"}
              </CardTitle>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setShowForm(false);
                  setEditingClub(null);
                }}
              >
                <X className="w-4 h-4" />
              </Button>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="col-span-2">
                    <label className="block text-sm font-medium mb-1">
                      Club Name *
                    </label>
                    <Input
                      value={formData.name}
                      onChange={(e) =>
                        setFormData({ ...formData, name: e.target.value })
                      }
                      placeholder="e.g., Driver, 7 Iron, 56° Wedge"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Club Type *
                    </label>
                    <Select
                      value={formData.club_type}
                      onChange={(e) =>
                        setFormData({
                          ...formData,
                          club_type: e.target.value as ClubType,
                        })
                      }
                      options={CLUB_TYPES.map((type) => ({
                        value: type.value,
                        label: `${type.icon} ${type.label}`,
                      }))}
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Loft (°)
                    </label>
                    <Input
                      type="number"
                      step="0.5"
                      value={formData.loft}
                      onChange={(e) =>
                        setFormData({ ...formData, loft: e.target.value })
                      }
                      placeholder="e.g., 10.5"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Brand
                    </label>
                    <Input
                      value={formData.brand}
                      onChange={(e) =>
                        setFormData({ ...formData, brand: e.target.value })
                      }
                      placeholder="e.g., TaylorMade"
                      list="brands"
                    />
                    <datalist id="brands">
                      {POPULAR_BRANDS.map((brand) => (
                        <option key={brand} value={brand} />
                      ))}
                    </datalist>
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Model
                    </label>
                    <Input
                      value={formData.model}
                      onChange={(e) =>
                        setFormData({ ...formData, model: e.target.value })
                      }
                      placeholder="e.g., Stealth 2"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Shaft Flex
                    </label>
                    <Input
                      value={formData.shaft}
                      onChange={(e) =>
                        setFormData({ ...formData, shaft: e.target.value })
                      }
                      placeholder="e.g., Stiff, Regular"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Shaft Material
                    </label>
                    <Select
                      value={formData.shaft_material}
                      onChange={(e) =>
                        setFormData({
                          ...formData,
                          shaft_material: e.target.value as "graphite" | "steel" | "",
                        })
                      }
                      placeholder="Select..."
                      options={[
                        { value: "graphite", label: "Graphite" },
                        { value: "steel", label: "Steel" },
                      ]}
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-1">
                      Avg Distance (yards)
                    </label>
                    <Input
                      type="number"
                      value={formData.avg_distance}
                      onChange={(e) =>
                        setFormData({ ...formData, avg_distance: e.target.value })
                      }
                      placeholder="e.g., 250"
                    />
                  </div>
                </div>

                <div className="flex gap-2 pt-4">
                  <Button type="submit" disabled={saving} className="flex-1">
                    {saving ? "Saving..." : editingClub ? "Update Club" : "Add Club"}
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => {
                      setShowForm(false);
                      setEditingClub(null);
                    }}
                  >
                    Cancel
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Clubs by Type */}
      {clubs.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center">
            <Target className="w-16 h-16 mx-auto text-foreground-muted mb-4" />
            <h3 className="text-lg font-semibold mb-2">Your bag is empty</h3>
            <p className="text-foreground-muted mb-4">
              Add your clubs to track distances and performance
            </p>
            <Button onClick={() => setShowForm(true)}>
              <Plus className="w-4 h-4 mr-2" />
              Add Your First Club
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {clubsByType.map((group) => (
            <Card key={group.value}>
              <button
                className="w-full px-6 py-4 flex items-center justify-between hover:bg-card-hover transition-colors"
                onClick={() =>
                  setExpandedType(
                    expandedType === group.value ? null : group.value
                  )
                }
              >
                <div className="flex items-center gap-3">
                  <span className="text-2xl">{group.icon}</span>
                  <div className="text-left">
                    <h3 className="font-semibold">{group.label}</h3>
                    <p className="text-sm text-foreground-muted">
                      {group.clubs.length} club{group.clubs.length !== 1 ? "s" : ""}
                    </p>
                  </div>
                </div>
                {expandedType === group.value ? (
                  <ChevronUp className="w-5 h-5" />
                ) : (
                  <ChevronDown className="w-5 h-5" />
                )}
              </button>

              {expandedType === group.value && (
                <CardContent className="border-t border-card-border">
                  {group.clubs.length === 0 ? (
                    <p className="text-foreground-muted text-center py-4">
                      No {group.label.toLowerCase()}s in your bag
                    </p>
                  ) : (
                    <div className="divide-y divide-card-border">
                      {group.clubs.map((club) => (
                        <div
                          key={club.id}
                          className="py-3 flex items-center justify-between"
                        >
                          <div>
                            <h4 className="font-medium">{club.name}</h4>
                            <p className="text-sm text-foreground-muted">
                              {[club.brand, club.model].filter(Boolean).join(" ") ||
                                "No details"}
                              {club.avg_distance && (
                                <span className="ml-2 text-accent-green">
                                  ~{club.avg_distance} yds
                                </span>
                              )}
                            </p>
                          </div>
                          <div className="flex items-center gap-2">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleEdit(club)}
                            >
                              <Edit2 className="w-4 h-4" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => toggleInBag(club)}
                            >
                              <X className="w-4 h-4" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleDelete(club.id)}
                              className="text-accent-red hover:text-accent-red"
                            >
                              <Trash2 className="w-4 h-4" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              )}
            </Card>
          ))}

          {/* Clubs not in bag */}
          {clubsNotInBag.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Not in Bag</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="divide-y divide-card-border">
                  {clubsNotInBag.map((club) => (
                    <div
                      key={club.id}
                      className="py-3 flex items-center justify-between opacity-60"
                    >
                      <div>
                        <h4 className="font-medium">{club.name}</h4>
                        <p className="text-sm text-foreground-muted">
                          {[club.brand, club.model].filter(Boolean).join(" ")}
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => toggleInBag(club)}
                        >
                          <Check className="w-4 h-4" />
                          Add to Bag
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleDelete(club.id)}
                          className="text-accent-red"
                        >
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      )}

      {/* Stats Summary */}
      {clubs.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Distance Chart</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {clubs
                .filter((c) => c.in_bag && c.avg_distance)
                .sort((a, b) => (b.avg_distance || 0) - (a.avg_distance || 0))
                .map((club) => (
                  <div key={club.id} className="flex items-center gap-4">
                    <div className="w-24 text-sm font-medium truncate">
                      {club.name}
                    </div>
                    <div className="flex-1 h-6 bg-background-tertiary rounded-full overflow-hidden">
                      <div
                        className="h-full bg-gradient-to-r from-accent-green to-accent-blue rounded-full transition-all"
                        style={{
                          width: `${((club.avg_distance || 0) / 300) * 100}%`,
                        }}
                      />
                    </div>
                    <div className="w-16 text-sm text-right">
                      {club.avg_distance} yds
                    </div>
                  </div>
                ))}
            </div>
            {!clubs.some((c) => c.in_bag && c.avg_distance) && (
              <p className="text-foreground-muted text-center py-4">
                Add average distances to your clubs to see the chart
              </p>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
