/**
 * Geolocation utilities for detecting user's country
 */

export interface UserLocation {
  country: string;
  countryCode: string;
  latitude?: number;
  longitude?: number;
}

/**
 * Get user's country from browser geolocation and reverse geocoding
 */
export async function getUserCountry(): Promise<UserLocation | null> {
  try {
    // Try to get location from browser
    if (!navigator.geolocation) {
      return getCountryFromTimezone();
    }

    return new Promise((resolve) => {
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          const { latitude, longitude } = position.coords;
          
          // Reverse geocode to get country
          try {
            const response = await fetch(
              `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=3&addressdetails=1`,
              {
                headers: {
                  'User-Agent': 'GolfStats App'
                }
              }
            );
            
            const data = await response.json();
            const country = data.address?.country;
            const countryCode = data.address?.country_code?.toUpperCase();
            
            if (country && countryCode) {
              resolve({
                country,
                countryCode,
                latitude,
                longitude,
              });
              return;
            }
          } catch (error) {
            console.error("Reverse geocoding failed:", error);
          }
          
          // Fallback to timezone
          resolve(getCountryFromTimezone());
        },
        () => {
          // Geolocation failed, use timezone fallback
          resolve(getCountryFromTimezone());
        },
        { timeout: 5000, maximumAge: 3600000 } // 1 hour cache
      );
    });
  } catch (error) {
    console.error("Error getting user country:", error);
    return getCountryFromTimezone();
  }
}

/**
 * Fallback: Get country from timezone
 */
function getCountryFromTimezone(): UserLocation | null {
  try {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    
    // Map common timezones to countries
    const timezoneToCountry: Record<string, { country: string; code: string }> = {
      'America/New_York': { country: 'United States', code: 'US' },
      'America/Chicago': { country: 'United States', code: 'US' },
      'America/Denver': { country: 'United States', code: 'US' },
      'America/Los_Angeles': { country: 'United States', code: 'US' },
      'America/Toronto': { country: 'Canada', code: 'CA' },
      'America/Vancouver': { country: 'Canada', code: 'CA' },
      'Europe/London': { country: 'United Kingdom', code: 'GB' },
      'Europe/Paris': { country: 'France', code: 'FR' },
      'Europe/Berlin': { country: 'Germany', code: 'DE' },
      'Europe/Rome': { country: 'Italy', code: 'IT' },
      'Europe/Madrid': { country: 'Spain', code: 'ES' },
      'Europe/Amsterdam': { country: 'Netherlands', code: 'NL' },
      'Europe/Stockholm': { country: 'Sweden', code: 'SE' },
      'Europe/Oslo': { country: 'Norway', code: 'NO' },
      'Europe/Copenhagen': { country: 'Denmark', code: 'DK' },
      'Europe/Helsinki': { country: 'Finland', code: 'FI' },
      'Europe/Dublin': { country: 'Ireland', code: 'IE' },
      'Europe/Athens': { country: 'Greece', code: 'GR' },
      'Europe/Lisbon': { country: 'Portugal', code: 'PT' },
      'Europe/Vienna': { country: 'Austria', code: 'AT' },
      'Europe/Brussels': { country: 'Belgium', code: 'BE' },
      'Europe/Zurich': { country: 'Switzerland', code: 'CH' },
      'Asia/Tokyo': { country: 'Japan', code: 'JP' },
      'Asia/Shanghai': { country: 'China', code: 'CN' },
      'Asia/Hong_Kong': { country: 'Hong Kong', code: 'HK' },
      'Asia/Singapore': { country: 'Singapore', code: 'SG' },
      'Asia/Seoul': { country: 'South Korea', code: 'KR' },
      'Asia/Dubai': { country: 'United Arab Emirates', code: 'AE' },
      'Australia/Sydney': { country: 'Australia', code: 'AU' },
      'Australia/Melbourne': { country: 'Australia', code: 'AU' },
      'Pacific/Auckland': { country: 'New Zealand', code: 'NZ' },
      'America/Mexico_City': { country: 'Mexico', code: 'MX' },
      'America/Sao_Paulo': { country: 'Brazil', code: 'BR' },
      'America/Buenos_Aires': { country: 'Argentina', code: 'AR' },
      'Africa/Johannesburg': { country: 'South Africa', code: 'ZA' },
    };
    
    const countryInfo = timezoneToCountry[timezone];
    if (countryInfo) {
      return {
        country: countryInfo.country,
        countryCode: countryInfo.code,
      };
    }
    
    // Try to extract from timezone string
    if (timezone.includes('America')) {
      return { country: 'United States', countryCode: 'US' };
    }
    if (timezone.includes('Europe')) {
      return { country: 'United Kingdom', countryCode: 'GB' };
    }
    if (timezone.includes('Asia')) {
      return { country: 'Japan', code: 'JP' };
    }
    if (timezone.includes('Australia') || timezone.includes('Pacific')) {
      return { country: 'Australia', countryCode: 'AU' };
    }
    
    return null;
  } catch (error) {
    console.error("Error getting country from timezone:", error);
    return null;
  }
}

/**
 * Get country code from locale
 */
export function getCountryFromLocale(): string | null {
  try {
    const locale = navigator.language || (navigator as any).userLanguage;
    const parts = locale.split('-');
    return parts[1]?.toUpperCase() || null;
  } catch {
    return null;
  }
}
