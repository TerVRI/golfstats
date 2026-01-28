'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { 
  Search, 
  Check,
  X,
  ChevronLeft,
  ChevronRight,
  MapPin,
  Eye,
  Edit,
  AlertTriangle,
  RefreshCw
} from 'lucide-react';
import { Button } from '@/components/ui';
import Link from 'next/link';

interface Course {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string | null;
  is_verified: boolean;
  holes: number | null;
  par: number | null;
  latitude: number | null;
  longitude: number | null;
  hole_data: any[] | null;
  created_at: string;
  contributed_by: string | null;
}

export default function CoursesPage() {
  const supabase = createClientComponentClient();
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'verified' | 'unverified' | 'has_data' | 'no_data'>('all');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [stats, setStats] = useState({
    total: 0,
    verified: 0,
    withData: 0,
    contributed: 0,
  });
  const pageSize = 20;

  const fetchCourses = useCallback(async () => {
    setLoading(true);
    
    let query = supabase
      .from('courses')
      .select('id, name, city, state, country, is_verified, holes, par, latitude, longitude, hole_data, created_at, contributed_by', { count: 'exact' });

    // Apply search
    if (search) {
      query = query.or(`name.ilike.%${search}%,city.ilike.%${search}%,country.ilike.%${search}%`);
    }

    // Apply filters
    if (filter === 'verified') {
      query = query.eq('is_verified', true);
    } else if (filter === 'unverified') {
      query = query.eq('is_verified', false);
    } else if (filter === 'has_data') {
      query = query.not('hole_data', 'is', null);
    } else if (filter === 'no_data') {
      query = query.is('hole_data', null);
    }

    // Pagination
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;
    
    const { data, count, error } = await query
      .order('name', { ascending: true })
      .range(from, to);

    if (error) {
      console.error('Error fetching courses:', error);
    } else {
      setCourses(data || []);
      setTotalCount(count || 0);
    }

    // Fetch stats
    const [totalRes, verifiedRes, withDataRes, contributedRes] = await Promise.all([
      supabase.from('courses').select('id', { count: 'exact', head: true }),
      supabase.from('courses').select('id', { count: 'exact', head: true }).eq('is_verified', true),
      supabase.from('courses').select('id', { count: 'exact', head: true }).not('hole_data', 'is', null),
      supabase.from('courses').select('id', { count: 'exact', head: true }).not('contributed_by', 'is', null),
    ]);

    setStats({
      total: totalRes.count || 0,
      verified: verifiedRes.count || 0,
      withData: withDataRes.count || 0,
      contributed: contributedRes.count || 0,
    });

    setLoading(false);
  }, [supabase, search, filter, page]);

  useEffect(() => {
    fetchCourses();
  }, [fetchCourses]);

  const totalPages = Math.ceil(totalCount / pageSize);

  const handleVerify = async (courseId: string, verified: boolean) => {
    const { error } = await supabase
      .from('courses')
      .update({ is_verified: verified })
      .eq('id', courseId);

    if (!error) {
      fetchCourses();
    }
  };

  const getHoleDataStatus = (holeData: any[] | null) => {
    if (!holeData || holeData.length === 0) return 'none';
    if (holeData.length === 1 && holeData[0]?.hole_number <= 0) return 'placeholder';
    return 'complete';
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Courses</h1>
          <p className="text-foreground-muted">{totalCount.toLocaleString()} courses</p>
        </div>
        <Button onClick={fetchCourses} variant="secondary">
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">Total Courses</p>
          <p className="text-2xl font-bold text-foreground">{stats.total.toLocaleString()}</p>
        </div>
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">Verified</p>
          <p className="text-2xl font-bold text-accent-green">{stats.verified.toLocaleString()}</p>
        </div>
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">With Hole Data</p>
          <p className="text-2xl font-bold text-blue-500">{stats.withData.toLocaleString()}</p>
        </div>
        <div className="bg-card-background border border-card-border rounded-xl p-4">
          <p className="text-sm text-foreground-muted">User Contributed</p>
          <p className="text-2xl font-bold text-purple-500">{stats.contributed.toLocaleString()}</p>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-foreground-muted" />
          <input
            type="text"
            placeholder="Search by name, city, or country..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="w-full pl-10 pr-4 py-2 bg-card-background border border-card-border rounded-lg text-foreground placeholder:text-foreground-muted focus:outline-none focus:ring-2 focus:ring-accent-green"
          />
        </div>
        <div className="flex flex-wrap gap-2">
          {(['all', 'verified', 'unverified', 'has_data', 'no_data'] as const).map((f) => (
            <button
              key={f}
              onClick={() => { setFilter(f); setPage(1); }}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                filter === f
                  ? 'bg-accent-green text-white'
                  : 'bg-card-background border border-card-border text-foreground-muted hover:text-foreground'
              }`}
            >
              {f === 'has_data' ? 'Has Data' : f === 'no_data' ? 'No Data' : f.charAt(0).toUpperCase() + f.slice(1)}
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
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Course</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Location</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Details</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Data</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Status</th>
                <th className="text-right px-6 py-3 text-xs font-medium text-foreground-muted uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-card-border">
              {loading ? (
                [...Array(5)].map((_, i) => (
                  <tr key={i}>
                    <td colSpan={6} className="px-6 py-4">
                      <div className="animate-pulse h-6 bg-background-secondary rounded" />
                    </td>
                  </tr>
                ))
              ) : courses.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-foreground-muted">
                    No courses found
                  </td>
                </tr>
              ) : (
                courses.map((course) => {
                  const dataStatus = getHoleDataStatus(course.hole_data);
                  
                  return (
                    <tr key={course.id} className="hover:bg-background-secondary/50">
                      <td className="px-6 py-4">
                        <p className="font-medium text-foreground">{course.name}</p>
                        {course.contributed_by && (
                          <p className="text-xs text-purple-500">User contributed</p>
                        )}
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-start gap-1">
                          <MapPin className="w-4 h-4 text-foreground-muted shrink-0 mt-0.5" />
                          <div className="text-sm text-foreground-muted">
                            {[course.city, course.state, course.country].filter(Boolean).join(', ') || 'Unknown'}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-sm text-foreground-muted">
                        {course.holes && <span>{course.holes} holes</span>}
                        {course.holes && course.par && <span> · </span>}
                        {course.par && <span>Par {course.par}</span>}
                      </td>
                      <td className="px-6 py-4">
                        <span className={`text-xs px-2 py-1 rounded-full ${
                          dataStatus === 'complete' 
                            ? 'bg-accent-green/10 text-accent-green' 
                            : dataStatus === 'placeholder'
                            ? 'bg-yellow-500/10 text-yellow-500'
                            : 'bg-gray-500/10 text-gray-500'
                        }`}>
                          {dataStatus === 'complete' 
                            ? `${course.hole_data?.filter(h => h.hole_number > 0).length || 0} holes`
                            : dataStatus === 'placeholder'
                            ? 'Placeholder'
                            : 'None'
                          }
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        {course.is_verified ? (
                          <span className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded-full bg-accent-green/10 text-accent-green">
                            <Check className="w-3 h-3" />
                            Verified
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded-full bg-yellow-500/10 text-yellow-500">
                            <AlertTriangle className="w-3 h-3" />
                            Unverified
                          </span>
                        )}
                      </td>
                      <td className="px-6 py-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <Link
                            href={`/courses/${course.id}`}
                            className="p-2 hover:bg-background-secondary rounded-lg transition-colors"
                            title="View"
                          >
                            <Eye className="w-4 h-4 text-foreground-muted" />
                          </Link>
                          {!course.is_verified ? (
                            <button
                              onClick={() => handleVerify(course.id, true)}
                              className="p-2 hover:bg-accent-green/10 rounded-lg transition-colors"
                              title="Verify"
                            >
                              <Check className="w-4 h-4 text-accent-green" />
                            </button>
                          ) : (
                            <button
                              onClick={() => handleVerify(course.id, false)}
                              className="p-2 hover:bg-red-500/10 rounded-lg transition-colors"
                              title="Unverify"
                            >
                              <X className="w-4 h-4 text-red-500" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between px-6 py-4 border-t border-card-border">
            <p className="text-sm text-foreground-muted">
              Showing {((page - 1) * pageSize) + 1} to {Math.min(page * pageSize, totalCount)} of {totalCount.toLocaleString()}
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
