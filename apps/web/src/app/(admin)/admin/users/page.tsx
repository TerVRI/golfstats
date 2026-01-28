'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { 
  Search, 
  Filter, 
  MoreVertical, 
  Crown, 
  Shield,
  Ban,
  Mail,
  ChevronLeft,
  ChevronRight,
  Download
} from 'lucide-react';
import { Button } from '@/components/ui';

interface User {
  id: string;
  email: string;
  full_name: string | null;
  created_at: string;
  subscription_tier: string | null;
  is_admin: boolean;
  rounds_count?: number;
}

export default function UsersPage() {
  const supabase = createClientComponentClient();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'pro' | 'free' | 'admin'>('all');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [actionMenuOpen, setActionMenuOpen] = useState<string | null>(null);
  const pageSize = 20;

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    
    let query = supabase
      .from('profiles')
      .select('id, email, full_name, created_at, subscription_tier, is_admin', { count: 'exact' });

    // Apply search
    if (search) {
      query = query.or(`email.ilike.%${search}%,full_name.ilike.%${search}%`);
    }

    // Apply filter
    if (filter === 'pro') {
      query = query.eq('subscription_tier', 'pro');
    } else if (filter === 'free') {
      query = query.or('subscription_tier.is.null,subscription_tier.eq.free');
    } else if (filter === 'admin') {
      query = query.eq('is_admin', true);
    }

    // Pagination
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;
    
    const { data, count, error } = await query
      .order('created_at', { ascending: false })
      .range(from, to);

    if (error) {
      console.error('Error fetching users:', error);
    } else {
      setUsers(data || []);
      setTotalCount(count || 0);
    }

    setLoading(false);
  }, [supabase, search, filter, page]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const totalPages = Math.ceil(totalCount / pageSize);

  const handleGrantPro = async (userId: string) => {
    const { error } = await supabase
      .from('profiles')
      .update({ subscription_tier: 'pro' })
      .eq('id', userId);

    if (!error) {
      fetchUsers();
    }
    setActionMenuOpen(null);
  };

  const handleRevokePro = async (userId: string) => {
    const { error } = await supabase
      .from('profiles')
      .update({ subscription_tier: 'free' })
      .eq('id', userId);

    if (!error) {
      fetchUsers();
    }
    setActionMenuOpen(null);
  };

  const handleGrantAdmin = async (userId: string) => {
    const { error } = await supabase.rpc('grant_admin', { p_user_id: userId });

    if (!error) {
      fetchUsers();
    }
    setActionMenuOpen(null);
  };

  const handleRevokeAdmin = async (userId: string) => {
    const { error } = await supabase.rpc('revoke_admin', { p_user_id: userId });

    if (!error) {
      fetchUsers();
    }
    setActionMenuOpen(null);
  };

  const exportUsers = async () => {
    const { data } = await supabase
      .from('profiles')
      .select('id, email, full_name, created_at, subscription_tier')
      .order('created_at', { ascending: false });

    if (data) {
      const csv = [
        ['ID', 'Email', 'Name', 'Created At', 'Subscription'].join(','),
        ...data.map(u => [u.id, u.email, u.full_name || '', u.created_at, u.subscription_tier || 'free'].join(','))
      ].join('\n');

      const blob = new Blob([csv], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `users-${new Date().toISOString().split('T')[0]}.csv`;
      a.click();
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Users</h1>
          <p className="text-foreground-muted">{totalCount.toLocaleString()} total users</p>
        </div>
        <Button onClick={exportUsers} variant="secondary">
          <Download className="w-4 h-4 mr-2" />
          Export CSV
        </Button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-foreground-muted" />
          <input
            type="text"
            placeholder="Search by email or name..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="w-full pl-10 pr-4 py-2 bg-card-background border border-card-border rounded-lg text-foreground placeholder:text-foreground-muted focus:outline-none focus:ring-2 focus:ring-accent-green"
          />
        </div>
        <div className="flex gap-2">
          {(['all', 'pro', 'free', 'admin'] as const).map((f) => (
            <button
              key={f}
              onClick={() => { setFilter(f); setPage(1); }}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === f
                  ? 'bg-accent-green text-white'
                  : 'bg-card-background border border-card-border text-foreground-muted hover:text-foreground'
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="bg-card-background border border-card-border rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-card-border">
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">User</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Status</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Joined</th>
                <th className="text-right px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-card-border">
              {loading ? (
                [...Array(5)].map((_, i) => (
                  <tr key={i}>
                    <td colSpan={4} className="px-6 py-4">
                      <div className="animate-pulse h-6 bg-background-secondary rounded" />
                    </td>
                  </tr>
                ))
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-6 py-12 text-center text-foreground-muted">
                    No users found
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id} className="hover:bg-background-secondary/50">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-accent-green/10 flex items-center justify-center">
                          <span className="text-accent-green font-medium">
                            {(user.full_name || user.email)?.[0]?.toUpperCase() || '?'}
                          </span>
                        </div>
                        <div>
                          <p className="font-medium text-foreground">{user.full_name || 'Anonymous'}</p>
                          <p className="text-sm text-foreground-muted">{user.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        {user.is_admin && (
                          <span className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded-full bg-red-500/10 text-red-500">
                            <Shield className="w-3 h-3" />
                            Admin
                          </span>
                        )}
                        <span className={`text-xs px-2 py-1 rounded-full ${
                          user.subscription_tier === 'pro'
                            ? 'bg-accent-green/10 text-accent-green'
                            : 'bg-gray-500/10 text-gray-500'
                        }`}>
                          {user.subscription_tier === 'pro' ? (
                            <span className="flex items-center gap-1">
                              <Crown className="w-3 h-3" />
                              Pro
                            </span>
                          ) : (
                            'Free'
                          )}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-foreground-muted">
                      {new Date(user.created_at).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="relative">
                        <button
                          onClick={() => setActionMenuOpen(actionMenuOpen === user.id ? null : user.id)}
                          className="p-2 hover:bg-card-background rounded-lg transition-colors"
                        >
                          <MoreVertical className="w-4 h-4 text-foreground-muted" />
                        </button>
                        {actionMenuOpen === user.id && (
                          <div className="absolute right-0 top-full mt-1 w-48 bg-card-background border border-card-border rounded-lg shadow-lg z-10">
                            <div className="py-1">
                              <a
                                href={`mailto:${user.email}`}
                                className="flex items-center gap-2 px-4 py-2 text-sm text-foreground hover:bg-background-secondary"
                              >
                                <Mail className="w-4 h-4" />
                                Send Email
                              </a>
                              {user.subscription_tier !== 'pro' ? (
                                <button
                                  onClick={() => handleGrantPro(user.id)}
                                  className="flex items-center gap-2 px-4 py-2 text-sm text-foreground hover:bg-background-secondary w-full text-left"
                                >
                                  <Crown className="w-4 h-4" />
                                  Grant Pro Access
                                </button>
                              ) : (
                                <button
                                  onClick={() => handleRevokePro(user.id)}
                                  className="flex items-center gap-2 px-4 py-2 text-sm text-red-500 hover:bg-background-secondary w-full text-left"
                                >
                                  <Crown className="w-4 h-4" />
                                  Revoke Pro Access
                                </button>
                              )}
                              {!user.is_admin ? (
                                <button
                                  onClick={() => handleGrantAdmin(user.id)}
                                  className="flex items-center gap-2 px-4 py-2 text-sm text-foreground hover:bg-background-secondary w-full text-left"
                                >
                                  <Shield className="w-4 h-4" />
                                  Make Admin
                                </button>
                              ) : (
                                <button
                                  onClick={() => handleRevokeAdmin(user.id)}
                                  className="flex items-center gap-2 px-4 py-2 text-sm text-red-500 hover:bg-background-secondary w-full text-left"
                                >
                                  <Shield className="w-4 h-4" />
                                  Remove Admin
                                </button>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
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
