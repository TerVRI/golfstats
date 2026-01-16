import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  RefreshControl,
} from 'react-native';
import { supabase } from '../lib/supabase';
import { useAuth } from '../hooks/useAuth';
import { formatSG, formatDate } from '@golfstats/shared';

interface Round {
  id: string;
  course_name: string;
  played_at: string;
  total_score: number;
  sg_total: number | null;
}

interface Stats {
  roundsPlayed: number;
  avgScore: number;
  bestScore: number;
  avgSG: number;
}

export function DashboardScreen({ navigation }: any) {
  const { user, signOut } = useAuth();
  const [rounds, setRounds] = useState<Round[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchData = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('rounds')
        .select('id, course_name, played_at, total_score, sg_total')
        .eq('user_id', user.id)
        .order('played_at', { ascending: false })
        .limit(10);

      if (error) throw error;

      setRounds(data || []);

      if (data && data.length > 0) {
        const scores = data.map((r) => r.total_score);
        const sgValues = data.filter((r) => r.sg_total != null).map((r) => r.sg_total!);
        
        setStats({
          roundsPlayed: data.length,
          avgScore: Math.round(scores.reduce((a, b) => a + b, 0) / scores.length),
          bestScore: Math.min(...scores),
          avgSG: sgValues.length > 0
            ? sgValues.reduce((a, b) => a + b, 0) / sgValues.length
            : 0,
        });
      }
    } catch (err) {
      console.error('Error fetching data:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [user]);

  const onRefresh = () => {
    setRefreshing(true);
    fetchData();
  };

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#10b981" />
      }
    >
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>Welcome back,</Text>
          <Text style={styles.name}>{user?.user_metadata?.full_name || 'Golfer'}</Text>
        </View>
        <TouchableOpacity onPress={signOut} style={styles.signOutBtn}>
          <Text style={styles.signOutText}>Sign Out</Text>
        </TouchableOpacity>
      </View>

      {/* Quick Stats */}
      <View style={styles.statsGrid}>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{stats?.roundsPlayed || 0}</Text>
          <Text style={styles.statLabel}>Rounds</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{stats?.avgScore || '-'}</Text>
          <Text style={styles.statLabel}>Avg Score</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statValue}>{stats?.bestScore || '-'}</Text>
          <Text style={styles.statLabel}>Best</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={[styles.statValue, stats && stats.avgSG >= 0 ? styles.positive : styles.negative]}>
            {stats ? formatSG(stats.avgSG) : '-'}
          </Text>
          <Text style={styles.statLabel}>Avg SG</Text>
        </View>
      </View>

      {/* Action Buttons */}
      <View style={styles.actionRow}>
        <TouchableOpacity
          style={styles.primaryButton}
          onPress={() => navigation.navigate('NewRound')}
        >
          <Text style={styles.primaryButtonText}>+ New Round</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.secondaryButton}
          onPress={() => navigation.navigate('LiveRound')}
        >
          <Text style={styles.secondaryButtonText}>🎯 Live GPS</Text>
        </TouchableOpacity>
      </View>

      {/* Recent Rounds */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Recent Rounds</Text>
        {rounds.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyText}>No rounds yet. Start logging!</Text>
          </View>
        ) : (
          rounds.map((round) => (
            <TouchableOpacity
              key={round.id}
              style={styles.roundCard}
              onPress={() => navigation.navigate('RoundDetail', { id: round.id })}
            >
              <View>
                <Text style={styles.courseName}>{round.course_name}</Text>
                <Text style={styles.roundDate}>{formatDate(round.played_at)}</Text>
              </View>
              <View style={styles.roundStats}>
                <Text style={styles.score}>{round.total_score}</Text>
                {round.sg_total != null && (
                  <Text style={[styles.sg, round.sg_total >= 0 ? styles.positive : styles.negative]}>
                    {formatSG(round.sg_total)}
                  </Text>
                )}
              </View>
            </TouchableOpacity>
          ))
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    paddingTop: 60,
  },
  greeting: {
    color: '#94a3b8',
    fontSize: 14,
  },
  name: {
    color: '#f8fafc',
    fontSize: 24,
    fontWeight: 'bold',
  },
  signOutBtn: {
    padding: 8,
  },
  signOutText: {
    color: '#94a3b8',
    fontSize: 14,
  },
  statsGrid: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    gap: 8,
  },
  statCard: {
    flex: 1,
    backgroundColor: '#1e293b',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  statValue: {
    color: '#f8fafc',
    fontSize: 24,
    fontWeight: 'bold',
  },
  statLabel: {
    color: '#94a3b8',
    fontSize: 12,
    marginTop: 4,
  },
  positive: {
    color: '#10b981',
  },
  negative: {
    color: '#f43f5e',
  },
  actionRow: {
    flexDirection: 'row',
    padding: 20,
    gap: 12,
  },
  primaryButton: {
    flex: 1,
    backgroundColor: '#10b981',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 16,
  },
  secondaryButton: {
    flex: 1,
    backgroundColor: '#1e293b',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#334155',
  },
  secondaryButtonText: {
    color: '#f8fafc',
    fontWeight: '600',
    fontSize: 16,
  },
  section: {
    padding: 20,
  },
  sectionTitle: {
    color: '#f8fafc',
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
  },
  emptyState: {
    backgroundColor: '#1e293b',
    borderRadius: 12,
    padding: 32,
    alignItems: 'center',
  },
  emptyText: {
    color: '#94a3b8',
    fontSize: 14,
  },
  roundCard: {
    backgroundColor: '#1e293b',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  courseName: {
    color: '#f8fafc',
    fontSize: 16,
    fontWeight: '600',
  },
  roundDate: {
    color: '#94a3b8',
    fontSize: 12,
    marginTop: 4,
  },
  roundStats: {
    alignItems: 'flex-end',
  },
  score: {
    color: '#f8fafc',
    fontSize: 24,
    fontWeight: 'bold',
  },
  sg: {
    fontSize: 14,
    fontWeight: '500',
  },
});
