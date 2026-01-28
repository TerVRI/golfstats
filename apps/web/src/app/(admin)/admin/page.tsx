'use client';

import { useEffect, useState } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { 
  Users, 
  CreditCard, 
  Flag, 
  TrendingUp,
  ArrowUpRight,
  ArrowDownRight,
  Activity,
  DollarSign
} from 'lucide-react';
import Link from 'next/link';

interface AdminStats {
  total_users: number;
  new_users_7d: number;
  new_users_30d: number;
  total_rounds: number;
  new_rounds_7d: number;
  total_courses: number;
  active_subscriptions: number;
  apple_subscriptions: number;
  stripe_subscriptions: number;
}

export default function AdminDashboard() {
  const supabase = createClientComponentClient();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [recentUsers, setRecentUsers] = useState<any[]>([]);
  const [recentSubscriptions, setRecentSubscriptions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      // Fetch stats
      const { data: statsData } = await supabase
        .from('admin_stats')
        .select('*')
        .single();

      if (statsData) {
        setStats(statsData);
      } else {
        // Fallback: fetch individual counts
        const [usersRes, roundsRes, coursesRes, subsRes] = await Promise.all([
          supabase.from('profiles').select('id', { count: 'exact', head: true }),
          supabase.from('rounds').select('id', { count: 'exact', head: true }),
          supabase.from('courses').select('id', { count: 'exact', head: true }),
          supabase.from('subscriptions').select('id', { count: 'exact', head: true }).in('status', ['active', 'trialing']),
        ]);

        setStats({
          total_users: usersRes.count || 0,
          new_users_7d: 0,
          new_users_30d: 0,
          total_rounds: roundsRes.count || 0,
          new_rounds_7d: 0,
          total_courses: coursesRes.count || 0,
          active_subscriptions: subsRes.count || 0,
          apple_subscriptions: 0,
          stripe_subscriptions: 0,
        });
      }

      // Fetch recent users
      const { data: users } = await supabase
        .from('profiles')
        .select('id, email, full_name, created_at, subscription_tier')
        .order('created_at', { ascending: false })
        .limit(5);

      setRecentUsers(users || []);

      // Fetch recent subscriptions
      const { data: subs } = await supabase
        .from('subscriptions')
        .select('id, user_id, source, plan, status, created_at')
        .order('created_at', { ascending: false })
        .limit(5);

      setRecentSubscriptions(subs || []);

      setLoading(false);
    };

    fetchData();
  }, [supabase]);

  if (loading) {
    return (
      <div className="animate-pulse space-y-8">
        <div className="h-8 bg-card-background rounded w-48" />
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="h-32 bg-card-background rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-foreground">Admin Dashboard</h1>
        <p className="text-foreground-muted">Overview of your application metrics</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Users"
          value={stats?.total_users || 0}
          change={stats?.new_users_7d || 0}
          changeLabel="new this week"
          icon={Users}
          href="/admin/users"
        />
        <StatCard
          title="Active Subscriptions"
          value={stats?.active_subscriptions || 0}
          subValue={`${stats?.apple_subscriptions || 0} Apple, ${stats?.stripe_subscriptions || 0} Stripe`}
          icon={CreditCard}
          href="/admin/subscriptions"
          positive
        />
        <StatCard
          title="Total Rounds"
          value={stats?.total_rounds || 0}
          change={stats?.new_rounds_7d || 0}
          changeLabel="this week"
          icon={Activity}
          href="/admin/analytics"
        />
        <StatCard
          title="Total Courses"
          value={stats?.total_courses || 0}
          icon={Flag}
          href="/admin/courses"
        />
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Users */}
        <div className="bg-card-background border border-card-border rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-foreground">Recent Users</h2>
            <Link href="/admin/users" className="text-sm text-accent-green hover:underline">
              View all
            </Link>
          </div>
          <div className="space-y-3">
            {recentUsers.map((user) => (
              <div key={user.id} className="flex items-center justify-between py-2 border-b border-card-border last:border-0">
                <div>
                  <p className="text-sm font-medium text-foreground">{user.full_name || 'Anonymous'}</p>
                  <p className="text-xs text-foreground-muted">{user.email}</p>
                </div>
                <div className="text-right">
                  <span className={`text-xs px-2 py-1 rounded-full ${
                    user.subscription_tier === 'pro' 
                      ? 'bg-accent-green/10 text-accent-green' 
                      : 'bg-gray-500/10 text-gray-500'
                  }`}>
                    {user.subscription_tier || 'free'}
                  </span>
                </div>
              </div>
            ))}
            {recentUsers.length === 0 && (
              <p className="text-sm text-foreground-muted text-center py-4">No users yet</p>
            )}
          </div>
        </div>

        {/* Recent Subscriptions */}
        <div className="bg-card-background border border-card-border rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-foreground">Recent Subscriptions</h2>
            <Link href="/admin/subscriptions" className="text-sm text-accent-green hover:underline">
              View all
            </Link>
          </div>
          <div className="space-y-3">
            {recentSubscriptions.map((sub) => (
              <div key={sub.id} className="flex items-center justify-between py-2 border-b border-card-border last:border-0">
                <div>
                  <p className="text-sm font-medium text-foreground capitalize">{sub.plan} Plan</p>
                  <p className="text-xs text-foreground-muted capitalize">via {sub.source}</p>
                </div>
                <div className="text-right">
                  <span className={`text-xs px-2 py-1 rounded-full ${
                    sub.status === 'active' 
                      ? 'bg-accent-green/10 text-accent-green' 
                      : sub.status === 'trialing'
                      ? 'bg-blue-500/10 text-blue-500'
                      : 'bg-red-500/10 text-red-500'
                  }`}>
                    {sub.status}
                  </span>
                </div>
              </div>
            ))}
            {recentSubscriptions.length === 0 && (
              <p className="text-sm text-foreground-muted text-center py-4">No subscriptions yet</p>
            )}
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-card-background border border-card-border rounded-xl p-6">
        <h2 className="font-semibold text-foreground mb-4">Quick Actions</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Link
            href="/admin/users?filter=new"
            className="p-4 rounded-lg border border-card-border hover:border-accent-green/50 transition-colors text-center"
          >
            <Users className="w-6 h-6 text-accent-green mx-auto mb-2" />
            <span className="text-sm text-foreground">New Users</span>
          </Link>
          <Link
            href="/admin/subscriptions?filter=expiring"
            className="p-4 rounded-lg border border-card-border hover:border-accent-green/50 transition-colors text-center"
          >
            <CreditCard className="w-6 h-6 text-accent-green mx-auto mb-2" />
            <span className="text-sm text-foreground">Expiring Soon</span>
          </Link>
          <Link
            href="/admin/courses?filter=unverified"
            className="p-4 rounded-lg border border-card-border hover:border-accent-green/50 transition-colors text-center"
          >
            <Flag className="w-6 h-6 text-accent-green mx-auto mb-2" />
            <span className="text-sm text-foreground">Review Courses</span>
          </Link>
          <Link
            href="/admin/analytics"
            className="p-4 rounded-lg border border-card-border hover:border-accent-green/50 transition-colors text-center"
          >
            <TrendingUp className="w-6 h-6 text-accent-green mx-auto mb-2" />
            <span className="text-sm text-foreground">Analytics</span>
          </Link>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  title,
  value,
  change,
  changeLabel,
  subValue,
  icon: Icon,
  href,
  positive = true,
}: {
  title: string;
  value: number;
  change?: number;
  changeLabel?: string;
  subValue?: string;
  icon: React.ComponentType<{ className?: string }>;
  href: string;
  positive?: boolean;
}) {
  return (
    <Link href={href}>
      <div className="bg-card-background border border-card-border rounded-xl p-6 hover:border-accent-green/50 transition-colors">
        <div className="flex items-start justify-between mb-4">
          <div className="w-10 h-10 rounded-lg bg-accent-green/10 flex items-center justify-center">
            <Icon className="w-5 h-5 text-accent-green" />
          </div>
          {change !== undefined && change > 0 && (
            <div className={`flex items-center gap-1 text-xs ${positive ? 'text-accent-green' : 'text-red-500'}`}>
              {positive ? <ArrowUpRight className="w-3 h-3" /> : <ArrowDownRight className="w-3 h-3" />}
              +{change}
            </div>
          )}
        </div>
        <p className="text-2xl font-bold text-foreground">{value.toLocaleString()}</p>
        <p className="text-sm text-foreground-muted">{title}</p>
        {subValue && <p className="text-xs text-foreground-muted mt-1">{subValue}</p>}
        {changeLabel && change !== undefined && (
          <p className="text-xs text-foreground-muted mt-1">+{change} {changeLabel}</p>
        )}
      </div>
    </Link>
  );
}
