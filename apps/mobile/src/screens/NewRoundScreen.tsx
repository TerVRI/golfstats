import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { supabase } from '../lib/supabase';
import { useAuth } from '../hooks/useAuth';

export function NewRoundScreen({ navigation }: any) {
  const { user } = useAuth();
  const [courseName, setCourseName] = useState('');
  const [courseRating, setCourseRating] = useState('');
  const [slopeRating, setSlopeRating] = useState('');
  const [totalScore, setTotalScore] = useState('');
  const [totalPutts, setTotalPutts] = useState('');
  const [fairwaysHit, setFairwaysHit] = useState('');
  const [fairwaysTotal, setFairwaysTotal] = useState('14');
  const [gir, setGir] = useState('');
  const [penalties, setPenalties] = useState('0');
  const [loading, setLoading] = useState(false);

  const saveRound = async () => {
    if (!courseName || !totalScore) {
      Alert.alert('Error', 'Please fill in required fields (Course Name, Total Score)');
      return;
    }

    setLoading(true);
    try {
      const { error } = await supabase.from('rounds').insert({
        user_id: user?.id,
        course_name: courseName,
        course_rating: courseRating ? parseFloat(courseRating) : null,
        slope_rating: slopeRating ? parseInt(slopeRating) : null,
        played_at: new Date().toISOString().split('T')[0],
        total_score: parseInt(totalScore),
        total_putts: totalPutts ? parseInt(totalPutts) : null,
        fairways_hit: fairwaysHit ? parseInt(fairwaysHit) : null,
        fairways_total: parseInt(fairwaysTotal),
        gir: gir ? parseInt(gir) : null,
        penalties: parseInt(penalties),
        scoring_format: 'stroke',
      });

      if (error) throw error;

      Alert.alert('Success', 'Round saved!', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (err: any) {
      Alert.alert('Error', err.message || 'Failed to save round');
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backBtn}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>New Round</Text>
          <View style={{ width: 50 }} />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Course Info</Text>
          <TextInput
            style={styles.input}
            placeholder="Course Name *"
            placeholderTextColor="#64748b"
            value={courseName}
            onChangeText={setCourseName}
          />
          <View style={styles.row}>
            <TextInput
              style={[styles.input, styles.halfInput]}
              placeholder="Course Rating"
              placeholderTextColor="#64748b"
              value={courseRating}
              onChangeText={setCourseRating}
              keyboardType="decimal-pad"
            />
            <TextInput
              style={[styles.input, styles.halfInput]}
              placeholder="Slope Rating"
              placeholderTextColor="#64748b"
              value={slopeRating}
              onChangeText={setSlopeRating}
              keyboardType="number-pad"
            />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Score</Text>
          <TextInput
            style={[styles.input, styles.scoreInput]}
            placeholder="Total Score *"
            placeholderTextColor="#64748b"
            value={totalScore}
            onChangeText={setTotalScore}
            keyboardType="number-pad"
          />
          <TextInput
            style={styles.input}
            placeholder="Total Putts"
            placeholderTextColor="#64748b"
            value={totalPutts}
            onChangeText={setTotalPutts}
            keyboardType="number-pad"
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Stats</Text>
          <View style={styles.row}>
            <TextInput
              style={[styles.input, styles.halfInput]}
              placeholder="Fairways Hit"
              placeholderTextColor="#64748b"
              value={fairwaysHit}
              onChangeText={setFairwaysHit}
              keyboardType="number-pad"
            />
            <TextInput
              style={[styles.input, styles.halfInput]}
              placeholder="of Total"
              placeholderTextColor="#64748b"
              value={fairwaysTotal}
              onChangeText={setFairwaysTotal}
              keyboardType="number-pad"
            />
          </View>
          <TextInput
            style={styles.input}
            placeholder="Greens in Regulation"
            placeholderTextColor="#64748b"
            value={gir}
            onChangeText={setGir}
            keyboardType="number-pad"
          />
          <TextInput
            style={styles.input}
            placeholder="Penalties"
            placeholderTextColor="#64748b"
            value={penalties}
            onChangeText={setPenalties}
            keyboardType="number-pad"
          />
        </View>

        <TouchableOpacity
          style={[styles.saveButton, loading && styles.saveButtonDisabled]}
          onPress={saveRound}
          disabled={loading}
        >
          <Text style={styles.saveButtonText}>
            {loading ? 'Saving...' : 'Save Round'}
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    paddingBottom: 40,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    paddingTop: 60,
  },
  backBtn: {
    color: '#10b981',
    fontSize: 16,
  },
  title: {
    color: '#f8fafc',
    fontSize: 20,
    fontWeight: '600',
  },
  section: {
    padding: 20,
    paddingTop: 0,
  },
  sectionTitle: {
    color: '#94a3b8',
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    marginBottom: 12,
  },
  input: {
    backgroundColor: '#1e293b',
    borderRadius: 12,
    padding: 16,
    color: '#f8fafc',
    fontSize: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#334155',
  },
  scoreInput: {
    fontSize: 24,
    textAlign: 'center',
    fontWeight: 'bold',
  },
  row: {
    flexDirection: 'row',
    gap: 12,
  },
  halfInput: {
    flex: 1,
  },
  saveButton: {
    backgroundColor: '#10b981',
    marginHorizontal: 20,
    paddingVertical: 18,
    borderRadius: 12,
    alignItems: 'center',
  },
  saveButtonDisabled: {
    opacity: 0.7,
  },
  saveButtonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 16,
  },
});
