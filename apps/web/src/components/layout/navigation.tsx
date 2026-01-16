"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { useUser } from "@/hooks/useUser";
import { ThemeToggle } from "@/components/theme-toggle";
import {
  LayoutDashboard,
  PlusCircle,
  History,
  TrendingUp,
  Menu,
  X,
  Target,
  LogOut,
  User,
  Dumbbell,
  Trophy,
  Flag,
  Briefcase,
  Award,
  MapPin,
} from "lucide-react";
import { useState } from "react";

const navItems = [
  {
    href: "/dashboard",
    label: "Dashboard",
    icon: LayoutDashboard,
  },
  {
    href: "/rounds/new",
    label: "New Round",
    icon: PlusCircle,
  },
  {
    href: "/rounds",
    label: "Round History",
    icon: History,
  },
  {
    href: "/trends",
    label: "Trends",
    icon: TrendingUp,
  },
  {
    href: "/bag",
    label: "My Bag",
    icon: Briefcase,
  },
  {
    href: "/achievements",
    label: "Achievements",
    icon: Award,
  },
  {
    href: "/practice",
    label: "Practice Log",
    icon: Dumbbell,
  },
  {
    href: "/goals",
    label: "Goals",
    icon: Flag,
  },
  {
    href: "/courses",
    label: "Courses",
    icon: MapPin,
  },
  {
    href: "/leaderboard",
    label: "Leaderboard",
    icon: Trophy,
  },
  {
    href: "/profile",
    label: "Profile",
    icon: User,
  },
];

export function Navigation() {
  const pathname = usePathname();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const { user, signOut } = useUser();

  const userInitial = user?.email?.charAt(0).toUpperCase() || "U";
  const userEmail = user?.email || "";
  const userName = user?.user_metadata?.full_name || user?.user_metadata?.name || userEmail.split("@")[0];

  return (
    <>
      {/* Desktop Sidebar */}
      <aside className="hidden md:flex md:w-64 md:flex-col md:fixed md:inset-y-0 bg-background-secondary border-r border-card-border">
        {/* Logo */}
        <div className="flex items-center gap-3 px-6 py-5 border-b border-card-border">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
            <Target className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-foreground">RoundCaddy</h1>
            <p className="text-xs text-foreground-muted">Strokes Gained Analytics</p>
          </div>
        </div>

        {/* Navigation Links */}
        <nav className="flex-1 px-4 py-6 space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href || pathname.startsWith(item.href + "/");
            
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200",
                  isActive
                    ? "bg-accent-green/10 text-accent-green"
                    : "text-foreground-muted hover:text-foreground hover:bg-background-tertiary"
                )}
              >
                <Icon className="w-5 h-5" />
                <span className="font-medium">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* User Section */}
        <div className="px-4 py-4 border-t border-card-border">
          {user && (
            <div className="flex items-center gap-3 px-2 mb-3">
              <div className="w-8 h-8 rounded-full bg-accent-green/20 flex items-center justify-center text-accent-green font-medium text-sm">
                {userInitial}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-foreground truncate">{userName}</p>
                <p className="text-xs text-foreground-muted truncate">{userEmail}</p>
              </div>
              <ThemeToggle />
            </div>
          )}
          <button
            onClick={signOut}
            className="flex items-center gap-3 px-4 py-2 w-full rounded-lg text-foreground-muted hover:text-accent-red hover:bg-accent-red/10 transition-colors"
          >
            <LogOut className="w-4 h-4" />
            <span className="text-sm font-medium">Sign Out</span>
          </button>
        </div>
      </aside>

      {/* Mobile Header */}
      <header className="md:hidden fixed top-0 inset-x-0 z-50 bg-background-secondary border-b border-card-border">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
              <Target className="w-5 h-5 text-white" />
            </div>
            <h1 className="text-lg font-bold text-foreground">RoundCaddy</h1>
          </div>
          
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="p-2 text-foreground-muted hover:text-foreground rounded-lg hover:bg-background-tertiary transition-colors"
          >
            {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>

        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <nav className="px-4 py-4 space-y-1 bg-background-secondary border-t border-card-border animate-fade-in">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive = pathname === item.href || pathname.startsWith(item.href + "/");
              
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setMobileMenuOpen(false)}
                  className={cn(
                    "flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200",
                    isActive
                      ? "bg-accent-green/10 text-accent-green"
                      : "text-foreground-muted hover:text-foreground hover:bg-background-tertiary"
                  )}
                >
                  <Icon className="w-5 h-5" />
                  <span className="font-medium">{item.label}</span>
                </Link>
              );
            })}

            {/* Mobile User Section */}
            <div className="pt-4 mt-4 border-t border-card-border">
              {user && (
                <div className="flex items-center gap-3 px-4 py-2 mb-2">
                  <div className="w-8 h-8 rounded-full bg-accent-green/20 flex items-center justify-center text-accent-green font-medium text-sm">
                    {userInitial}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-foreground truncate">{userName}</p>
                    <p className="text-xs text-foreground-muted truncate">{userEmail}</p>
                  </div>
                </div>
              )}
              <button
                onClick={signOut}
                className="flex items-center gap-3 px-4 py-3 w-full rounded-lg text-foreground-muted hover:text-accent-red hover:bg-accent-red/10 transition-colors"
              >
                <LogOut className="w-5 h-5" />
                <span className="font-medium">Sign Out</span>
              </button>
            </div>
          </nav>
        )}
      </header>
    </>
  );
}
