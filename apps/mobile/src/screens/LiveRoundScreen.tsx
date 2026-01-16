import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Dimensions,
} from 'react-native';
import * as Location from 'expo-location';
import { supabase } from '../lib/supabase';
import { useAuth } from '../hooks/useAuth';
import { calculateDistance } from '@golfstats/shared';

interface GreenLocation {
  front: { lat: number; lon: number };
  center: { lat: number; lon: number };
  back: { lat: number; lon: number };
}

interface Shot {
  id: string;
  holeNumber: number;
  shotNumber: number;
  club: string | null;
  lat: number;
  lon: number;
  timestamp: Date;
}

export function LiveRoundScreen({ navigation, route }: any) {
  const { user } = useAuth();
  const [location, setLocation] = useState<Location.LocationObject | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isTracking, setIsTracking] = useState(false);
  const [currentHole, setCurrentHole] = useState(1);
  const [shots, setShots] = useState<Shot[]>([]);
  const [lastShotLocation, setLastShotLocation] = useState<{ lat: number; lon: number } | null>(null);
  const locationSubscription = useRef<Location.LocationSubscription | null>(null);

  // Demo green location - in real app, this comes from course data
  const [greenLocation] = useState<GreenLocation>({
    front: { lat: 0, lon: 0 },
    center: { lat: 0, lon: 0 },
    back: { lat: 0, lon: 0 },
  });

  useEffect(() => {
    (async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setErrorMsg('Location permission is required to use GPS features.');
        return;
      }

      // Get initial location
      const loc = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.BestForNavigation,
      });
      setLocation(loc);
    })();

    return () => {
      if (locationSubscription.current) {
        locationSubscription.current.remove();
      }
    };
  }, []);

  const startTracking = async () => {
    setIsTracking(true);
    locationSubscription.current = await Location.watchPositionAsync(
      {
        accuracy: Location.Accuracy.BestForNavigation,
        distanceInterval: 1, // meters
        timeInterval: 1000, // ms
      },
      (loc) => {
        setLocation(loc);
      }
    );
  };

  const stopTracking = () => {
    setIsTracking(false);
    if (locationSubscription.current) {
      locationSubscription.current.remove();
      locationSubscription.current = null;
    }
  };

  const markShot = (club?: string) => {
    if (!location) {
      Alert.alert('Error', 'Unable to get current location.');
      return;
    }

    const newShot: Shot = {
      id: Date.now().toString(),
      holeNumber: currentHole,
      shotNumber: shots.filter((s) => s.holeNumber === currentHole).length + 1,
      club: club || null,
      lat: location.coords.latitude,
      lon: location.coords.longitude,
      timestamp: new Date(),
    };

    setShots((prev) => [...prev, newShot]);
    setLastShotLocation({ lat: newShot.lat, lon: newShot.lon });
  };

  const calculateDistanceToGreen = (): { front: number; center: number; back: number } | null => {
    if (!location || !greenLocation.center.lat) {
      return null;
    }

    const lat = location.coords.latitude;
    const lon = location.coords.longitude;

    return {
      front: calculateDistance(lat, lon, greenLocation.front.lat, greenLocation.front.lon, 'yards'),
      center: calculateDistance(lat, lon, greenLocation.center.lat, greenLocation.center.lon, 'yards'),
      back: calculateDistance(lat, lon, greenLocation.back.lat, greenLocation.back.lon, 'yards'),
    };
  };

  const getLastShotDistance = (): number | null => {
    if (!location || !lastShotLocation) return null;
    return calculateDistance(
      lastShotLocation.lat,
      lastShotLocation.lon,
      location.coords.latitude,
      location.coords.longitude,
      'yards'
    );
  };

  const nextHole = () => {
    if (currentHole < 18) {
      setCurrentHole((prev) => prev + 1);
      setLastShotLocation(null);
    } else {
      Alert.alert('Round Complete', 'Would you like to save this round?', [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Save', onPress: () => saveRound() },
      ]);
    }
  };

  const prevHole = () => {
    if (currentHole > 1) {
      setCurrentHole((prev) => prev - 1);
      // Find last shot on previous hole
      const prevHoleShots = shots.filter((s) => s.holeNumber === currentHole - 1);
      if (prevHoleShots.length > 0) {
        const lastShot = prevHoleShots[prevHoleShots.length - 1];
        setLastShotLocation({ lat: lastShot.lat, lon: lastShot.lon });
      } else {
        setLastShotLocation(null);
      }
    }
  };

  const saveRound = async () => {
    // TODO: Implement save round with shots data to Supabase
    Alert.alert('Success', 'Round saved!');
    navigation.goBack();
  };

  const distances = calculateDistanceToGreen();
  const lastShotDist = getLastShotDistance();
  const currentHoleShots = shots.filter((s) => s.holeNumber === currentHole);

  if (errorMsg) {
    return (
      <View style={styles.container}>
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{errorMsg}</Text>
          <TouchableOpacity
            style={styles.button}
            onPress={() => navigation.goBack()}
          >
            <Text style={styles.buttonText}>Go Back</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Hole Indicator */}
      <View style={styles.holeNav}>
        <TouchableOpacity onPress={prevHole} disabled={currentHole === 1}>
          <Text style={[styles.navArrow, currentHole === 1 && styles.disabled]}>◀</Text>
        </TouchableOpacity>
        <View style={styles.holeInfo}>
          <Text style={styles.holeNumber}>Hole {currentHole}</Text>
          <Text style={styles.holeStats}>{currentHoleShots.length} shots</Text>
        </View>
        <TouchableOpacity onPress={nextHole}>
          <Text style={styles.navArrow}>▶</Text>
        </TouchableOpacity>
      </View>

      {/* Distance Display */}
      <View style={styles.distanceContainer}>
        {distances ? (
          <>
            <View style={styles.distanceRow}>
              <Text style={styles.distanceLabel}>Front</Text>
              <Text style={styles.distanceValue}>{distances.front} yds</Text>
            </View>
            <View style={[styles.distanceRow, styles.centerDistance]}>
              <Text style={styles.distanceLabel}>Center</Text>
              <Text style={styles.distanceBig}>{distances.center}</Text>
              <Text style={styles.distanceUnit}>yds</Text>
            </View>
            <View style={styles.distanceRow}>
              <Text style={styles.distanceLabel}>Back</Text>
              <Text style={styles.distanceValue}>{distances.back} yds</Text>
            </View>
          </>
        ) : (
          <View style={styles.noDistance}>
            <Text style={styles.noDistanceText}>
              {isTracking ? 'Calculating distances...' : 'Start tracking to see distances'}
            </Text>
            <Text style={styles.noDistanceSubtext}>
              Course GPS data will be added soon
            </Text>
          </View>
        )}
      </View>

      {/* Last Shot Distance */}
      {lastShotDist !== null && (
        <View style={styles.lastShotContainer}>
          <Text style={styles.lastShotLabel}>Last Shot Distance</Text>
          <Text style={styles.lastShotValue}>{lastShotDist} yards</Text>
        </View>
      )}

      {/* GPS Status */}
      <View style={styles.gpsStatus}>
        <View style={[styles.gpsIndicator, isTracking ? styles.gpsActive : styles.gpsInactive]} />
        <Text style={styles.gpsText}>
          {isTracking ? 'GPS Active' : 'GPS Inactive'}
        </Text>
        {location && (
          <Text style={styles.coordsText}>
            {location.coords.latitude.toFixed(6)}, {location.coords.longitude.toFixed(6)}
          </Text>
        )}
      </View>

      {/* Action Buttons */}
      <View style={styles.actions}>
        {!isTracking ? (
          <TouchableOpacity style={styles.primaryButton} onPress={startTracking}>
            <Text style={styles.primaryButtonText}>Start Round</Text>
          </TouchableOpacity>
        ) : (
          <>
            <TouchableOpacity style={styles.markButton} onPress={() => markShot()}>
              <Text style={styles.markButtonText}>Mark Shot</Text>
            </TouchableOpacity>

            {/* Club Quick Select */}
            <View style={styles.clubGrid}>
              {['Driver', '3W', '5W', '4i', '5i', '6i', '7i', '8i', '9i', 'PW', 'SW', 'Putter'].map((club) => (
                <TouchableOpacity
                  key={club}
                  style={styles.clubButton}
                  onPress={() => markShot(club)}
                >
                  <Text style={styles.clubText}>{club}</Text>
                </TouchableOpacity>
              ))}
            </View>

            <TouchableOpacity style={styles.stopButton} onPress={stopTracking}>
              <Text style={styles.stopButtonText}>End Round</Text>
            </TouchableOpacity>
          </>
        )}
      </View>
    </View>
  );
}

const { width } = Dimensions.get('window');

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  holeNav: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 20,
    paddingTop: 60,
    borderBottomWidth: 1,
    borderBottomColor: '#1e293b',
  },
  navArrow: {
    fontSize: 24,
    color: '#10b981',
    padding: 10,
  },
  disabled: {
    color: '#334155',
  },
  holeInfo: {
    alignItems: 'center',
  },
  holeNumber: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#f8fafc',
  },
  holeStats: {
    fontSize: 14,
    color: '#94a3b8',
  },
  distanceContainer: {
    padding: 20,
    alignItems: 'center',
  },
  distanceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 4,
  },
  centerDistance: {
    marginVertical: 16,
  },
  distanceLabel: {
    color: '#94a3b8',
    fontSize: 14,
    marginRight: 8,
    width: 50,
  },
  distanceValue: {
    color: '#f8fafc',
    fontSize: 18,
    fontWeight: '600',
  },
  distanceBig: {
    color: '#10b981',
    fontSize: 64,
    fontWeight: 'bold',
  },
  distanceUnit: {
    color: '#94a3b8',
    fontSize: 18,
    marginLeft: 8,
  },
  noDistance: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  noDistanceText: {
    color: '#94a3b8',
    fontSize: 16,
  },
  noDistanceSubtext: {
    color: '#64748b',
    fontSize: 12,
    marginTop: 8,
  },
  lastShotContainer: {
    backgroundColor: '#1e293b',
    marginHorizontal: 20,
    padding: 16,
    borderRadius: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  lastShotLabel: {
    color: '#94a3b8',
    fontSize: 14,
  },
  lastShotValue: {
    color: '#f8fafc',
    fontSize: 20,
    fontWeight: 'bold',
  },
  gpsStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 12,
    gap: 8,
  },
  gpsIndicator: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  gpsActive: {
    backgroundColor: '#10b981',
  },
  gpsInactive: {
    backgroundColor: '#64748b',
  },
  gpsText: {
    color: '#94a3b8',
    fontSize: 12,
  },
  coordsText: {
    color: '#64748b',
    fontSize: 10,
  },
  actions: {
    flex: 1,
    padding: 20,
    justifyContent: 'flex-end',
  },
  primaryButton: {
    backgroundColor: '#10b981',
    paddingVertical: 20,
    borderRadius: 16,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#ffffff',
    fontWeight: 'bold',
    fontSize: 18,
  },
  markButton: {
    backgroundColor: '#10b981',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 12,
  },
  markButtonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 16,
  },
  clubGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 20,
  },
  clubButton: {
    width: (width - 40 - 32) / 4 - 2,
    backgroundColor: '#1e293b',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  clubText: {
    color: '#f8fafc',
    fontSize: 12,
    fontWeight: '600',
  },
  stopButton: {
    backgroundColor: '#1e293b',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#f43f5e',
  },
  stopButtonText: {
    color: '#f43f5e',
    fontWeight: '600',
    fontSize: 16,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
  },
  errorText: {
    color: '#f43f5e',
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 20,
  },
  button: {
    backgroundColor: '#1e293b',
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 12,
  },
  buttonText: {
    color: '#f8fafc',
    fontWeight: '600',
  },
});
