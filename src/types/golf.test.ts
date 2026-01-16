import { describe, it, expect } from 'vitest'
import { calculateStablefordPoints, createDefaultHoleData, DEFAULT_COURSE_PARS } from './golf'

describe('Golf Types and Utilities', () => {
  describe('calculateStablefordPoints', () => {
    it('should return 2 points for par', () => {
      expect(calculateStablefordPoints(4, 4)).toBe(2)
      expect(calculateStablefordPoints(3, 3)).toBe(2)
      expect(calculateStablefordPoints(5, 5)).toBe(2)
    })

    it('should return 3 points for birdie', () => {
      expect(calculateStablefordPoints(3, 4)).toBe(3)
      expect(calculateStablefordPoints(2, 3)).toBe(3)
      expect(calculateStablefordPoints(4, 5)).toBe(3)
    })

    it('should return 4 points for eagle', () => {
      expect(calculateStablefordPoints(2, 4)).toBe(4)
      expect(calculateStablefordPoints(3, 5)).toBe(4)
    })

    it('should return 5 points for albatross or better', () => {
      expect(calculateStablefordPoints(1, 4)).toBe(5) // Hole-in-one on par 4
      expect(calculateStablefordPoints(2, 5)).toBe(5) // Albatross
    })

    it('should return 1 point for bogey', () => {
      expect(calculateStablefordPoints(5, 4)).toBe(1)
      expect(calculateStablefordPoints(4, 3)).toBe(1)
    })

    it('should return 0 points for double bogey or worse', () => {
      expect(calculateStablefordPoints(6, 4)).toBe(0)
      expect(calculateStablefordPoints(7, 4)).toBe(0)
      expect(calculateStablefordPoints(5, 3)).toBe(0)
    })

    it('should handle handicap strokes', () => {
      // With 1 handicap stroke, a 5 on par 4 becomes net 4 (par) = 2 points
      expect(calculateStablefordPoints(5, 4, 1)).toBe(2)
      // With 2 handicap strokes, a 6 on par 4 becomes net 4 (par) = 2 points
      expect(calculateStablefordPoints(6, 4, 2)).toBe(2)
    })
  })

  describe('createDefaultHoleData', () => {
    it('should create hole data with correct hole number', () => {
      const hole = createDefaultHoleData(7)
      expect(hole.hole_number).toBe(7)
    })

    it('should default par to 4', () => {
      const hole = createDefaultHoleData(1)
      expect(hole.par).toBe(4)
    })

    it('should allow custom par', () => {
      const hole3 = createDefaultHoleData(3, 3)
      const hole5 = createDefaultHoleData(5, 5)
      expect(hole3.par).toBe(3)
      expect(hole5.par).toBe(5)
    })

    it('should default score to par', () => {
      const hole = createDefaultHoleData(1, 5)
      expect(hole.score).toBe(5)
    })

    it('should default putts to 2', () => {
      const hole = createDefaultHoleData(1)
      expect(hole.putts).toBe(2)
    })

    it('should default GIR to false', () => {
      const hole = createDefaultHoleData(1)
      expect(hole.gir).toBe(false)
    })

    it('should default penalties to 0', () => {
      const hole = createDefaultHoleData(1)
      expect(hole.penalties).toBe(0)
    })
  })

  describe('DEFAULT_COURSE_PARS', () => {
    it('should have 18 holes', () => {
      expect(DEFAULT_COURSE_PARS).toHaveLength(18)
    })

    it('should total to 72 (standard par)', () => {
      const total = DEFAULT_COURSE_PARS.reduce((sum, par) => sum + par, 0)
      expect(total).toBe(72)
    })

    it('should contain par 3s, 4s, and 5s', () => {
      expect(DEFAULT_COURSE_PARS).toContain(3)
      expect(DEFAULT_COURSE_PARS).toContain(4)
      expect(DEFAULT_COURSE_PARS).toContain(5)
    })
  })
})
