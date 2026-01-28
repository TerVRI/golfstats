'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { 
  Search, 
  Apple,
  CreditCard,
  ChevronLeft,
  ChevronRight,
  ExternalLink,
  RefreshCw,
  AlertCircle
} from 'lucide-react';
import { Button } from '@/components/ui';

interface Subscription {
  id: string;
  user_id: string;
  source: 'apple' | 'stripe' | 'promo';
  plan: 'monthly' | 'annual';
  status: 'active' | 'trialing' | 'past_due' | 'cancelled' | 'expired';
  price_cents: number | null;
  currency: string | null;
  current_period_start: string | null;
  current_period_end: string | null;
  trial_end: string | null;
  cancelled_at: string | null;
  stripe_subscription_id: string | null;
  stripe_customer_id: string | null;
  apple_original_transaction_id: string | null;
  created_at: string;
  profiles?: {
    email: string;
    full_name: string | null;
  };
}

export default function SubscriptionsPage() {
  const supabase = createClientComponentClient();
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'active' | 'trialing' | 'cancelled' | 'apple' | 'stripe'>('all');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [stats, setStats] = useState({
    total: 0,
    active: 0,
    trialing: 0,
    cancelled: 0,
    mrr: 0,
  });
  const pageSize = 20;

  const fetchSubscriptions = useCallback(async () => {
    setLoading(true);
    
    let query = supabase
      .from('subscriptions')
      .select(`
        *,
        profiles:user_id (email, full_name)
      `, { count: 'exact' });

    // Apply filters
    if (filter === 'active') {
      query = query.eq('status', 'active');
    } else if (filter === 'trialing') {
      query = query.eq('status', 'trialing');
    } else if (filter === 'cancelled') {
      query = query.in('status', ['cancelled', 'expired']);
    } else if (filter === 'apple') {
      query = query.eq('source', 'apple');
    } else if (filter === 'stripe') {
      query = query.eq('source', 'stripe');
    }

    // Pagination
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;
    
    const { data, count, error } = await query
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      console.error('Error fetching subscriptions:', error);
    } else {
      setSubscriptions(data || []);
      setTotalCount(count || 0);
    }

    // Fetch stats
    const [activeRes, trialingRes, cancelledRes] = await Promise.all([
      supabase.from('subscriptions').select('id, price_cents', { count: 'exact' }).eq('status', 'active'),
      supabase.from('subscriptions').select('id', { count: 'exact' }).eq('status', 'trialing'),
      supabase.from('subscriptions').select('id', { count: 'exact' }).in('status', ['cancelled', 'expired']),
    ]);

    // Calculate MRR
    let mrr = 0;
    activeRes.data?.forEach(sub => {
      if (sub.price_cents) {
        // Normalize to monthly
        mrr += sub.price_cents; // Assuming monthly, would need plan check for annual
      }
    });

    setStats({
      total: (activeRes.count || 0) + (trialingRes.count || 0),
      active: activeRes.count || 0,
      trialing: trialingRes.count || 0,
      cancelled: cancelledRes.count || 0,
      mrr: mrr / 100,
    });

    setLoading(false);
  }, [supabase, filter, page]);

  useEffect(() => {
    fetchSubscriptions();
  }, [fetchSubscriptions]);

  const totalPages = Math.ceil(totalCount / pageSize);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-accent-green/10 text-accent-green';
      case 'trialing':
        return 'bg-blue-500/10 text-blue-500';
      case 'past_due':
        return 'bg-yellow-500/10 text-yellow-500';
      case 'cancelled':
      case 'expired':
        return 'bg-red-500/10 text-red-500';
      default:
        return 'bg-gray-500/10 text-gray-500';
    }
  };

  const formatPrice = (cents: number | null, currency: string | null) => {
    if (!cents) return '-';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency || 'USD',
    }).format(cents / 100);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Subscriptions</h1>
          <p className="text-foreground-muted">{totalCount.toLocaleString()} total subscriptions</p>
        </div>
        <Button onClick={fetchSubscriptions} variant="secondary">
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">Active Subscriptions</p>
          <p className="text-2xl font-bold text-foreground">{stats.active}</p>
        </div>
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">In Trial</p>
          <p className="text-2xl font-bold text-blue-500">{stats.trialing}</p>
        </div>
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">Cancelled</p>
          <p className="text-2xl font-bold text-red-500">{stats.cancelled}</p>
        </div>
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">Est. MRR</p>
          <p className="text-2xl font-bold text-accent-green">${stats.mrr.toFixed(0)}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-2">
        {(['all', 'active', 'trialing', 'cancelled', 'apple', 'stripe'] as const).map((f) => (
          <button
            key={f}
            onClick={() => { setFilter(f); setPage(1); }}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center gap-2 ${
              filter === f
                ? 'bg-accent-green text-white'
                : 'bg-card-background border border-card-border text-foreground-muted hover:text-foreground'
            }`}
          >
            {f === 'apple' && <Apple className="w-4 h-4" />}
            {f === 'stripe' && <CreditCard className="w-4 h-4" />}
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="bg-card-background border border-card-border rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-card-border">
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">User</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Plan</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Source</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Status</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Period End</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Price</th>
                <th className="text-right px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-card-border">
              {loading ? (
                [...Array(5)].map((_, i) => (
                  <tr key={i}>
                    <td colSpan={7} className="px-6 py-4">
                      <div className="animate-pulse h-6 bg-background-secondary rounded" />
                    </td>
                  </tr>
                ))
              ) : subscriptions.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-foreground-muted">
                    No subscriptions found
                  </td>
                </tr>
              ) : (
                subscriptions.map((sub) => (
                  <tr key={sub.id} className="hover:bg-background-secondary/50">
                    <td className="px-6 py-4">
                      <div>
                        <p className="font-medium text-foreground">
                          {sub.profiles?.full_name || 'Anonymous'}
                        </p>
                        <p className="text-sm text-foreground-muted">{sub.profiles?.email}</p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="capitalize text-foreground">{sub.plan}</span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        {sub.source === 'apple' ? (
                          <Apple className="w-4 h-4 text-foreground-muted" />
                        ) : sub.source === 'stripe' ? (
                          <CreditCard className="w-4 h-4 text-foreground-muted" />
                        ) : (
                          <span className="text-xs text-foreground-muted">Promo</span>
                        )}
                        <span className="capitalize text-foreground">{sub.source}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`text-xs px-2 py-1 rounded-full capitalize ${getStatusColor(sub.status)}`}>
                        {sub.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-foreground-muted">
                      {sub.current_period_end 
                        ? new Date(sub.current_period_end).toLocaleDateString()
                        : '-'
                      }
                      {sub.status === 'trialing' && sub.trial_end && (
                        <span className="block text-xs text-blue-500">
                          Trial ends {new Date(sub.trial_end).toLocaleDateString()}
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-sm text-foreground">
                      {formatPrice(sub.price_cents, sub.currency)}
                    </td>
                    <td className="px-6 py-4 text-right">
                      {sub.source === 'stripe' && sub.stripe_subscription_id && (
                        <a
                          href={`https://dashboard.stripe.com/subscriptions/${sub.stripe_subscription_id}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-sm text-accent-green hover:underline"
                        >
                          Stripe
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-card-border">
            <p className="text-sm text-foreground-muted">
              Showing {((page - 1) * pageSize) + 1} to {Math.min(page * pageSize, totalCount)} of {totalCount}
            </p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                className="p-2 rounded-lg hover:bg-background-secondary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <span className="text-sm text-foreground">
                Page {page} of {totalPages}
              </span>
              <button
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
                className="p-2 rounded-lg hover:bg-background-secondary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
