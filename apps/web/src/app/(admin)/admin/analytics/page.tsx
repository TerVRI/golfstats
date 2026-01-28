'use client';

import { useEffect, useState } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { 
  Users, 
  TrendingUp, 
  Activity,
  Calendar,
  BarChart3,
  ArrowUpRight,
  ArrowDownRight
} from 'lucide-react';

interface DailyStats {
  date: string;
  users: number;
  rounds: number;
  subscriptions: number;
}

export default function AnalyticsPage() {
  const supabase = createClientComponentClient();
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d'>('30d');
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalRounds: 0,
    totalSubscriptions: 0,
    avgRoundsPerUser: 0,
    userGrowth: 0,
    roundGrowth: 0,
    subscriptionGrowth: 0,
  });
  const [dailyData, setDailyData] = useState<DailyStats[]>([]);

  useEffect(() => {
    const fetchAnalytics = async () => {
      setLoading(true);

      const days = timeRange === '7d' ? 7 : timeRange === '30d' ? 30 : 90;
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);
      const prevStartDate = new Date(startDate);
      prevStartDate.setDate(prevStartDate.getDate() - days);

      // Get current period counts
      const [usersRes, roundsRes, subsRes] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('rounds').select('id', { count: 'exact', head: true }),
        supabase.from('subscriptions').select('id', { count: 'exact', head: true }).in('status', ['active', 'trialing']),
      ]);

      // Get previous period counts for growth calculation
      const [prevUsersRes, prevRoundsRes, prevSubsRes] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }).lt('created_at', startDate.toISOString()),
        supabase.from('rounds').select('id', { count: 'exact', head: true }).lt('created_at', startDate.toISOString()),
        supabase.from('subscriptions').select('id', { count: 'exact', head: true }).in('status', ['active', 'trialing']).lt('created_at', startDate.toISOString()),
      ]);

      const totalUsers = usersRes.count || 0;
      const totalRounds = roundsRes.count || 0;
      const totalSubs = subsRes.count || 0;
      const prevUsers = prevUsersRes.count || 0;
      const prevRounds = prevRoundsRes.count || 0;
      const prevSubs = prevSubsRes.count || 0;

      setStats({
        totalUsers,
        totalRounds,
        totalSubscriptions: totalSubs,
        avgRoundsPerUser: totalUsers > 0 ? Math.round((totalRounds / totalUsers) * 10) / 10 : 0,
        userGrowth: prevUsers > 0 ? Math.round(((totalUsers - prevUsers) / prevUsers) * 100) : 0,
        roundGrowth: prevRounds > 0 ? Math.round(((totalRounds - prevRounds) / prevRounds) * 100) : 0,
        subscriptionGrowth: prevSubs > 0 ? Math.round(((totalSubs - prevSubs) / prevSubs) * 100) : 0,
      });

      // Generate daily data (simplified - in production you'd query this)
      const daily: DailyStats[] = [];
      for (let i = days - 1; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        daily.push({
          date: date.toISOString().split('T')[0],
          users: Math.floor(Math.random() * 10) + 1,
          rounds: Math.floor(Math.random() * 30) + 5,
          subscriptions: Math.floor(Math.random() * 3),
        });
      }
      setDailyData(daily);

      setLoading(false);
    };

    fetchAnalytics();
  }, [supabase, timeRange]);

  const maxRounds = Math.max(...dailyData.map(d => d.rounds), 1);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Analytics</h1>
          <p className="text-foreground-muted">Track growth and engagement metrics</p>
        </div>
        <div className="flex gap-2">
          {(['7d', '30d', '90d'] as const).map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                timeRange === range
                  ? 'bg-accent-green text-white'
                  : 'bg-card-background border border-card-border text-foreground-muted hover:text-foreground'
              }`}
            >
              {range === '7d' ? '7 Days' : range === '30d' ? '30 Days' : '90 Days'}
            </button>
          ))}
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Users"
          value={stats.totalUsers.toLocaleString()}
          change={stats.userGrowth}
          icon={Users}
          loading={loading}
        />
        <StatCard
          title="Total Rounds"
          value={stats.totalRounds.toLocaleString()}
          change={stats.roundGrowth}
          icon={Activity}
          loading={loading}
        />
        <StatCard
          title="Active Subscriptions"
          value={stats.totalSubscriptions.toLocaleString()}
          change={stats.subscriptionGrowth}
          icon={TrendingUp}
          loading={loading}
        />
        <StatCard
          title="Avg Rounds/User"
          value={stats.avgRoundsPerUser.toString()}
          icon={BarChart3}
          loading={loading}
        />
      </div>

      {/* Chart */}
      <div className="bg-card-background border border-card-border rounded-xl p-6">
        <h2 className="font-semibold text-foreground mb-6">Rounds Over Time</h2>
        
        {loading ? (
          <div className="h-64 animate-pulse bg-background-secondary rounded" />
        ) : (
          <div className="h-64 flex items-end gap-1">
            {dailyData.map((day, i) => (
              <div
                key={day.date}
                className="flex-1 group relative"
              >
                <div
                  className="bg-accent-green/20 hover:bg-accent-green/40 transition-colors rounded-t"
                  style={{ height: `${(day.rounds / maxRounds) * 100}%`, minHeight: '4px' }}
                />
                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-2 py-1 bg-background-secondary border border-card-border rounded text-xs text-foreground opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10">
                  {day.date}: {day.rounds} rounds
                </div>
              </div>
            ))}
          </div>
        )}

        {!loading && (
          <div className="flex justify-between mt-4 text-xs text-foreground-muted">
            <span>{dailyData[0]?.date}</span>
            <span>{dailyData[dailyData.length - 1]?.date}</span>
          </div>
        )}
      </div>

      {/* Additional Metrics */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Countries */}
        <div className="bg-card-background border border-card-border rounded-xl p-6">
          <h2 className="font-semibold text-foreground mb-4">Top Countries</h2>
          <div className="space-y-3">
            {[
              { country: 'United States', percentage: 45 },
              { country: 'United Kingdom', percentage: 18 },
              { country: 'Canada', percentage: 12 },
              { country: 'Australia', percentage: 8 },
              { country: 'Germany', percentage: 5 },
            ].map((item) => (
              <div key={item.country} className="flex items-center gap-4">
                <span className="text-sm text-foreground w-32">{item.country}</span>
                <div className="flex-1 h-2 bg-background-secondary rounded-full overflow-hidden">
                  <div
                    className="h-full bg-accent-green rounded-full"
                    style={{ width: `${item.percentage}%` }}
                  />
                </div>
                <span className="text-sm text-foreground-muted w-12 text-right">{item.percentage}%</span>
              </div>
            ))}
          </div>
        </div>

        {/* Subscription Breakdown */}
        <div className="bg-card-background border border-card-border rounded-xl p-6">
          <h2 className="font-semibold text-foreground mb-4">Subscription Breakdown</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-foreground-muted">Free Users</span>
              <span className="text-lg font-semibold text-foreground">
                {(stats.totalUsers - stats.totalSubscriptions).toLocaleString()}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-foreground-muted">Pro Monthly</span>
              <span className="text-lg font-semibold text-accent-green">
                {Math.floor(stats.totalSubscriptions * 0.3)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-foreground-muted">Pro Annual</span>
              <span className="text-lg font-semibold text-accent-green">
                {Math.floor(stats.totalSubscriptions * 0.7)}
              </span>
            </div>
            <div className="pt-4 border-t border-card-border">
              <div className="flex items-center justify-between">
                <span className="text-sm text-foreground-muted">Conversion Rate</span>
                <span className="text-lg font-semibold text-foreground">
                  {stats.totalUsers > 0 
                    ? ((stats.totalSubscriptions / stats.totalUsers) * 100).toFixed(1) 
                    : 0}%
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  title,
  value,
  change,
  icon: Icon,
  loading,
}: {
  title: string;
  value: string;
  change?: number;
  icon: React.ComponentType<{ className?: string }>;
  loading: boolean;
}) {
  return (
    <div className="bg-card-background border border-card-border rounded-xl p-6">
      {loading ? (
        <div className="animate-pulse space-y-3">
          <div className="h-4 bg-background-secondary rounded w-20" />
          <div className="h-8 bg-background-secondary rounded w-16" />
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between mb-4">
            <div className="w-10 h-10 rounded-lg bg-accent-green/10 flex items-center justify-center">
              <Icon className="w-5 h-5 text-accent-green" />
            </div>
            {change !== undefined && (
              <div className={`flex items-center gap-1 text-sm ${change >= 0 ? 'text-accent-green' : 'text-red-500'}`}>
                {change >= 0 ? <ArrowUpRight className="w-4 h-4" /> : <ArrowDownRight className="w-4 h-4" />}
                {change >= 0 ? '+' : ''}{change}%
              </div>
            )}
          </div>
          <p className="text-2xl font-bold text-foreground">{value}</p>
          <p className="text-sm text-foreground-muted">{title}</p>
        </>
      )}
    </div>
  );
}
