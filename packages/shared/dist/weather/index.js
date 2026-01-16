// Weather integration using Open-Meteo API (free, no API key required)
const WEATHER_CODE_MAP = {
    0: { conditions: 'Clear sky', icon: '☀️' },
    1: { conditions: 'Mainly clear', icon: '🌤️' },
    2: { conditions: 'Partly cloudy', icon: '⛅' },
    3: { conditions: 'Overcast', icon: '☁️' },
    45: { conditions: 'Foggy', icon: '🌫️' },
    48: { conditions: 'Depositing rime fog', icon: '🌫️' },
    51: { conditions: 'Light drizzle', icon: '🌧️' },
    53: { conditions: 'Moderate drizzle', icon: '🌧️' },
    55: { conditions: 'Dense drizzle', icon: '🌧️' },
    61: { conditions: 'Slight rain', icon: '🌧️' },
    63: { conditions: 'Moderate rain', icon: '🌧️' },
    65: { conditions: 'Heavy rain', icon: '🌧️' },
    71: { conditions: 'Slight snow', icon: '🌨️' },
    73: { conditions: 'Moderate snow', icon: '🌨️' },
    75: { conditions: 'Heavy snow', icon: '❄️' },
    77: { conditions: 'Snow grains', icon: '🌨️' },
    80: { conditions: 'Slight rain showers', icon: '🌦️' },
    81: { conditions: 'Moderate rain showers', icon: '🌦️' },
    82: { conditions: 'Violent rain showers', icon: '⛈️' },
    85: { conditions: 'Slight snow showers', icon: '🌨️' },
    86: { conditions: 'Heavy snow showers', icon: '❄️' },
    95: { conditions: 'Thunderstorm', icon: '⛈️' },
    96: { conditions: 'Thunderstorm with hail', icon: '⛈️' },
    99: { conditions: 'Severe thunderstorm', icon: '⛈️' },
};
function getWindDirection(degrees) {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    const index = Math.round(degrees / 22.5) % 16;
    return directions[index];
}
function celsiusToFahrenheit(celsius) {
    return Math.round((celsius * 9) / 5 + 32);
}
function kmhToMph(kmh) {
    return Math.round(kmh * 0.621371);
}
function isGoodGolfWeather(temp, windSpeed, precipProb) {
    return temp >= 50 && temp <= 95 && windSpeed <= 20 && precipProb < 40;
}
export async function fetchWeather(latitude, longitude) {
    try {
        const url = new URL('https://api.open-meteo.com/v1/forecast');
        url.searchParams.set('latitude', latitude.toString());
        url.searchParams.set('longitude', longitude.toString());
        url.searchParams.set('current', 'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,uv_index');
        url.searchParams.set('hourly', 'temperature_2m,precipitation_probability,weather_code,wind_speed_10m,wind_direction_10m');
        url.searchParams.set('daily', 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code');
        url.searchParams.set('temperature_unit', 'celsius');
        url.searchParams.set('wind_speed_unit', 'kmh');
        url.searchParams.set('timezone', 'auto');
        url.searchParams.set('forecast_days', '5');
        const response = await fetch(url.toString());
        if (!response.ok)
            throw new Error('Weather fetch failed');
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const data = await response.json();
        // Parse current weather
        const currentCode = data.current.weather_code;
        const currentConditions = WEATHER_CODE_MAP[currentCode] || { conditions: 'Unknown', icon: '❓' };
        const currentTemp = celsiusToFahrenheit(data.current.temperature_2m);
        const currentWind = kmhToMph(data.current.wind_speed_10m);
        const currentPrecipProb = data.hourly.precipitation_probability[0] || 0;
        const current = {
            temperature: currentTemp,
            windSpeed: currentWind,
            windDirection: data.current.wind_direction_10m,
            windDirectionLabel: getWindDirection(data.current.wind_direction_10m),
            precipitation: data.current.precipitation,
            precipitationProbability: currentPrecipProb,
            humidity: data.current.relative_humidity_2m,
            uvIndex: data.current.uv_index,
            conditions: currentConditions.conditions,
            icon: currentConditions.icon,
            isGoodForGolf: isGoodGolfWeather(currentTemp, currentWind, currentPrecipProb),
        };
        // Parse hourly (next 12 hours)
        const hourly = data.hourly.time.slice(0, 12).map((time, i) => {
            const code = data.hourly.weather_code[i];
            const cond = WEATHER_CODE_MAP[code] || { conditions: 'Unknown', icon: '❓' };
            const temp = celsiusToFahrenheit(data.hourly.temperature_2m[i]);
            const wind = kmhToMph(data.hourly.wind_speed_10m[i]);
            const precip = data.hourly.precipitation_probability[i];
            return {
                time: new Date(time).toLocaleTimeString('en-US', { hour: 'numeric' }),
                temperature: temp,
                windSpeed: wind,
                windDirection: data.hourly.wind_direction_10m[i],
                windDirectionLabel: getWindDirection(data.hourly.wind_direction_10m[i]),
                precipitation: 0,
                precipitationProbability: precip,
                humidity: 0,
                uvIndex: 0,
                conditions: cond.conditions,
                icon: cond.icon,
                isGoodForGolf: isGoodGolfWeather(temp, wind, precip),
            };
        });
        // Parse daily forecast
        const daily = data.daily.time.map((date, i) => {
            const code = data.daily.weather_code[i];
            const cond = WEATHER_CODE_MAP[code] || { conditions: 'Unknown', icon: '❓' };
            return {
                date: new Date(date).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }),
                tempHigh: celsiusToFahrenheit(data.daily.temperature_2m_max[i]),
                tempLow: celsiusToFahrenheit(data.daily.temperature_2m_min[i]),
                conditions: cond.conditions,
                icon: cond.icon,
                precipitationProbability: data.daily.precipitation_probability_max[i],
            };
        });
        return { current, hourly, daily };
    }
    catch (error) {
        console.error('Weather fetch error:', error);
        return null;
    }
}
// Helper to determine wind impact on golf
export function getWindImpact(windSpeed, windDirection, shotDirection) {
    const diff = Math.abs(windDirection - shotDirection);
    const normalizedDiff = diff > 180 ? 360 - diff : diff;
    if (normalizedDiff <= 45 || normalizedDiff >= 315) {
        return 'tailwind';
    }
    else if (normalizedDiff >= 135 && normalizedDiff <= 225) {
        return 'headwind';
    }
    return 'crosswind';
}
