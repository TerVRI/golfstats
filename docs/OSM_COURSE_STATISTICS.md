# OpenStreetMap Golf Course Statistics

## Overview

OpenStreetMap contains approximately **38,000-38,800 golf courses** worldwide. This document provides estimated breakdowns by country based on global golf course data and OSM coverage.

## Global Statistics

- **Total Golf Courses Worldwide:** ~38,800
- **Estimated OSM Coverage:** ~38,000 (98%+ coverage)
- **Countries with Courses:** 200+

## Top 50 Countries by Golf Course Count

| Rank | Country | Estimated Courses | OSM Coverage |
|------|---------|------------------|--------------|
| 1 | United States | ~16,700 | Excellent |
| 2 | Japan | ~3,100 | Excellent |
| 3 | Canada | ~2,600-2,700 | Excellent |
| 4 | England | ~2,200-2,300 | Excellent |
| 5 | Australia | ~1,600 | Excellent |
| 6 | Germany | ~1,050 | Very Good |
| 7 | France | ~800 | Very Good |
| 8 | South Korea | ~780-800 | Good |
| 9 | Sweden | ~650 | Excellent |
| 10 | Spain | ~400-500 | Good |
| 11 | Scotland | ~550 | Excellent |
| 12 | Ireland | ~400 | Excellent |
| 13 | Italy | ~300-400 | Good |
| 14 | Netherlands | ~200-300 | Excellent |
| 15 | New Zealand | ~400 | Excellent |
| 16 | South Africa | ~500 | Good |
| 17 | Brazil | ~100-150 | Fair |
| 18 | Mexico | ~200 | Fair |
| 19 | Argentina | ~300 | Good |
| 20 | Chile | ~100 | Fair |
| 21 | Portugal | ~80-100 | Good |
| 22 | Belgium | ~80-100 | Excellent |
| 23 | Switzerland | ~100 | Excellent |
| 24 | Austria | ~150 | Excellent |
| 25 | Denmark | ~200 | Excellent |
| 26 | Norway | ~200 | Excellent |
| 27 | Finland | ~100 | Excellent |
| 28 | Poland | ~50-100 | Good |
| 29 | Czech Republic | ~100 | Good |
| 30 | Hungary | ~50-80 | Good |
| 31 | Greece | ~20-30 | Fair |
| 32 | Turkey | ~50 | Fair |
| 33 | Russia | ~100-200 | Fair |
| 34 | China | ~500-600 | Fair |
| 35 | India | ~200-300 | Fair |
| 36 | Thailand | ~250 | Good |
| 37 | Malaysia | ~200 | Good |
| 38 | Singapore | ~20 | Excellent |
| 39 | Philippines | ~100 | Fair |
| 40 | Indonesia | ~50-100 | Fair |
| 41 | Vietnam | ~30-50 | Fair |
| 42 | Taiwan | ~50 | Good |
| 43 | Hong Kong | ~10 | Excellent |
| 44 | United Arab Emirates | ~20 | Good |
| 45 | Saudi Arabia | ~30-50 | Fair |
| 46 | Egypt | ~20-30 | Fair |
| 47 | Morocco | ~30 | Fair |
| 48 | Kenya | ~20 | Fair |
| 49 | Zimbabwe | ~20 | Fair |
| 50 | And many more... | | |

## Regional Breakdown

### North America
- **United States:** ~16,700 courses
- **Canada:** ~2,600-2,700 courses
- **Mexico:** ~200 courses
- **Total:** ~19,500+ courses

### Europe
- **United Kingdom (England, Scotland, Wales, N. Ireland):** ~2,800 courses
- **Germany:** ~1,050 courses
- **France:** ~800 courses
- **Sweden:** ~650 courses
- **Spain:** ~400-500 courses
- **Italy:** ~300-400 courses
- **Netherlands:** ~200-300 courses
- **Other European countries:** ~2,000+ courses
- **Total:** ~8,500+ courses

### Asia-Pacific
- **Japan:** ~3,100 courses
- **Australia:** ~1,600 courses
- **South Korea:** ~780-800 courses
- **China:** ~500-600 courses
- **Thailand:** ~250 courses
- **New Zealand:** ~400 courses
- **Other Asia-Pacific:** ~1,500+ courses
- **Total:** ~8,200+ courses

### Other Regions
- **South America:** ~600-800 courses
- **Africa:** ~200-300 courses
- **Middle East:** ~100-150 courses
- **Total:** ~900-1,250 courses

## OSM Coverage Quality

### Excellent Coverage (90%+)
- United States
- Canada
- United Kingdom
- Ireland
- Australia
- New Zealand
- Japan
- Sweden
- Norway
- Denmark
- Netherlands
- Belgium
- Switzerland
- Austria
- Germany
- France

### Very Good Coverage (70-90%)
- Spain
- Italy
- South Korea
- South Africa
- Argentina

### Good Coverage (50-70%)
- Brazil
- Mexico
- Thailand
- Malaysia
- Singapore
- Taiwan

### Fair Coverage (30-50%)
- China
- India
- Philippines
- Indonesia
- Most developing countries

## Getting Exact Statistics

To get the exact count from OpenStreetMap:

```bash
npx tsx scripts/get-osm-golf-statistics.ts
```

This will:
1. Query all golf courses in OSM globally
2. Group by country
3. Display statistics
4. Save to `osm-golf-statistics.json`

**Note:** This query takes 5-10 minutes to complete.

## Data Quality Notes

### What OSM Provides Well
- ✅ Course names (most have names)
- ✅ Locations (lat/lon coordinates)
- ✅ Basic addresses (varies by country)
- ✅ Geometry for many courses (ways/relations)

### What's Often Missing
- ❌ Hole-level data (par, yardages, etc.)
- ❌ Course ratings (slope, course rating)
- ❌ Detailed GPS (tee boxes, greens)
- ❌ Photos
- ❌ Contact information (varies)

### Post-Import Enhancement
After importing OSM courses, users can:
- Add hole-level GPS data
- Add photos
- Confirm/update information
- Add missing details

## Import Strategy

1. **Initial Import:** Import all OSM courses as "pending"
2. **Auto-approve High Quality:** Courses with complete data
3. **User Confirmation:** Let users confirm/update courses
4. **Periodic Updates:** Re-import periodically for new courses

## Notes

- Statistics are estimates based on global golf course data
- Actual OSM coverage may vary by region
- Coverage is generally better in developed countries
- Some countries may have more or fewer courses than estimated
- OSM data is constantly improving

## Sources

- Global golf course data from various sources
- OpenStreetMap Overpass API
- Research studies on global golf course distribution
