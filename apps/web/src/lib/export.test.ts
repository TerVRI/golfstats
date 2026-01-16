import { describe, it, expect } from 'vitest'
import { roundsToCSV, clubStatsToCSV } from './export'

describe('Export Utilities', () => {
  describe('roundsToCSV', () => {
    it('should generate valid CSV with headers', () => {
      const rounds = [{
        played_at: '2024-01-15',
        course_name: 'Pebble Beach',
        total_score: 82,
        total_putts: 32,
        fairways_hit: 8,
        fairways_total: 14,
        gir: 10,
        penalties: 1,
        sg_total: -2.5,
        sg_off_tee: -0.5,
        sg_approach: -1.0,
        sg_around_green: 0.2,
        sg_putting: -1.2,
        course_rating: 75.5,
        slope_rating: 145,
        scoring_format: 'stroke',
      }]

      const csv = roundsToCSV(rounds)
      const lines = csv.split('\n')
      
      // First line should be headers
      expect(lines[0]).toContain('Date')
      expect(lines[0]).toContain('Course')
      expect(lines[0]).toContain('Score')
      
      // Second line should be data
      expect(lines[1]).toContain('2024-01-15')
      expect(lines[1]).toContain('Pebble Beach')
      expect(lines[1]).toContain('82')
    })

    it('should handle empty rounds array', () => {
      const csv = roundsToCSV([])
      const lines = csv.split('\n')
      
      // Should only have headers
      expect(lines).toHaveLength(1)
    })

    it('should quote course names with commas', () => {
      const rounds = [{
        played_at: '2024-01-15',
        course_name: 'Augusta National, GA',
        total_score: 72,
        total_putts: 30,
        fairways_hit: 12,
        fairways_total: 14,
        gir: 14,
        penalties: 0,
        sg_total: 5.0,
        sg_off_tee: 1.5,
        sg_approach: 2.0,
        sg_around_green: 0.5,
        sg_putting: 1.0,
        course_rating: 76.2,
        slope_rating: 148,
      }]

      const csv = roundsToCSV(rounds)
      
      // Course name should be quoted
      expect(csv).toContain('"Augusta National, GA"')
    })

    it('should handle null values gracefully', () => {
      const rounds = [{
        played_at: '2024-01-15',
        course_name: 'Test Course',
        total_score: 90,
        total_putts: null,
        fairways_hit: null,
        fairways_total: null,
        gir: null,
        penalties: null,
        sg_total: null,
        sg_off_tee: null,
        sg_approach: null,
        sg_around_green: null,
        sg_putting: null,
        course_rating: null,
        slope_rating: null,
      }]

      const csv = roundsToCSV(rounds)
      
      // Should contain N/A for null strokes gained values
      expect(csv).toContain('N/A')
    })
  })

  describe('clubStatsToCSV', () => {
    it('should generate valid CSV for clubs', () => {
      const clubs = [
        {
          name: 'Driver',
          brand: 'TaylorMade',
          model: 'Stealth 2',
          club_type: 'driver',
          avg_distance: 265,
          total_shots: 50,
        },
        {
          name: '7 Iron',
          brand: 'Titleist',
          model: 'T200',
          club_type: 'iron',
          avg_distance: 165,
          total_shots: 120,
        },
      ]

      const csv = clubStatsToCSV(clubs)
      const lines = csv.split('\n')
      
      // Headers
      expect(lines[0]).toContain('Club')
      expect(lines[0]).toContain('Avg Distance')
      
      // Data
      expect(lines[1]).toContain('Driver')
      expect(lines[1]).toContain('265')
      expect(lines[2]).toContain('7 Iron')
    })

    it('should handle missing optional fields', () => {
      const clubs = [
        {
          name: 'Putter',
          club_type: 'putter',
        },
      ]

      const csv = clubStatsToCSV(clubs)
      
      // Should not throw and should handle missing fields
      expect(csv).toContain('Putter')
      expect(csv).toContain('N/A')
    })
  })
})
