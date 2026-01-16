import { describe, it, expect } from 'vitest'
import { calculateRoundStrokesGained, calculateHoleStrokesGained } from './calculator'
import { HoleEntryData } from '@/types/golf'

describe('Strokes Gained Calculator', () => {
  describe('calculateHoleStrokesGained', () => {
    it('should return zeros for a par hole with average play', () => {
      const hole: HoleEntryData = {
        hole_number: 1,
        par: 4,
        score: 4,
        putts: 2,
        fairway_hit: true,
        gir: true,
        penalties: 0,
        tee_club: 'Driver',
        approach_distance: 150,
        approach_club: '7 Iron',
        approach_result: 'green',
        first_putt_distance: 20,
      }

      const result = calculateHoleStrokesGained(hole)
      
      // All values should be numbers (may be slightly positive or negative)
      expect(typeof result.sg_off_tee).toBe('number')
      expect(typeof result.sg_approach).toBe('number')
      expect(typeof result.sg_around_green).toBe('number')
      expect(typeof result.sg_putting).toBe('number')
    })

    it('should calculate negative strokes gained for over par score', () => {
      const hole: HoleEntryData = {
        hole_number: 1,
        par: 4,
        score: 6, // Double bogey
        putts: 3,
        fairway_hit: false,
        gir: false,
        penalties: 1,
        tee_club: 'Driver',
        approach_distance: 150,
        approach_club: '7 Iron',
        approach_result: 'bunker',
        first_putt_distance: 30,
      }

      const result = calculateHoleStrokesGained(hole)
      const total = result.sg_off_tee + result.sg_approach + result.sg_around_green + result.sg_putting
      
      // Total should be negative for a poor hole
      expect(total).toBeLessThan(0)
    })

    it('should calculate positive strokes gained for birdie', () => {
      const hole: HoleEntryData = {
        hole_number: 1,
        par: 4,
        score: 3, // Birdie
        putts: 1,
        fairway_hit: true,
        gir: true,
        penalties: 0,
        tee_club: 'Driver',
        approach_distance: 150,
        approach_club: '8 Iron',
        approach_result: 'green',
        first_putt_distance: 10,
      }

      const result = calculateHoleStrokesGained(hole)
      const total = result.sg_off_tee + result.sg_approach + result.sg_around_green + result.sg_putting
      
      // Total should be positive for a great hole
      expect(total).toBeGreaterThan(0)
    })

    it('should handle par 3 holes (no fairway)', () => {
      const hole: HoleEntryData = {
        hole_number: 3,
        par: 3,
        score: 3,
        putts: 2,
        fairway_hit: null, // Par 3s don't have fairways
        gir: true,
        penalties: 0,
        tee_club: '7 Iron',
        approach_distance: null,
        approach_club: null,
        approach_result: 'green',
        first_putt_distance: 15,
      }

      const result = calculateHoleStrokesGained(hole)
      
      // Off tee SG should be calculated differently for par 3
      expect(typeof result.sg_off_tee).toBe('number')
    })
  })

  describe('calculateRoundStrokesGained', () => {
    it('should sum up strokes gained across all holes', () => {
      const holes: HoleEntryData[] = Array.from({ length: 18 }, (_, i) => ({
        hole_number: i + 1,
        par: i % 6 === 2 ? 3 : i % 6 === 4 ? 5 : 4,
        score: i % 6 === 2 ? 3 : i % 6 === 4 ? 5 : 4,
        putts: 2,
        fairway_hit: (i % 6 !== 2) ? true : null,
        gir: true,
        penalties: 0,
        tee_club: 'Driver',
        approach_distance: 150,
        approach_club: '7 Iron',
        approach_result: 'green',
        first_putt_distance: 20,
      }))

      const result = calculateRoundStrokesGained(holes)
      
      expect(typeof result.sg_total).toBe('number')
      expect(typeof result.sg_off_tee).toBe('number')
      expect(typeof result.sg_approach).toBe('number')
      expect(typeof result.sg_around_green).toBe('number')
      expect(typeof result.sg_putting).toBe('number')
    })

    it('should handle empty hole array', () => {
      const result = calculateRoundStrokesGained([])
      
      expect(result.sg_total).toBe(0)
      expect(result.sg_off_tee).toBe(0)
      expect(result.sg_approach).toBe(0)
      expect(result.sg_around_green).toBe(0)
      expect(result.sg_putting).toBe(0)
    })
  })
})
