// Shared utility functions for all apps
export function formatNumber(num, decimals = 1) {
    return num.toFixed(decimals);
}
export function formatSG(value) {
    const prefix = value >= 0 ? "+" : "";
    return `${prefix}${value.toFixed(2)}`;
}
export function formatDate(date) {
    const d = typeof date === "string" ? new Date(date) : date;
    return d.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
    });
}
export function formatDateShort(date) {
    const d = typeof date === "string" ? new Date(date) : date;
    return d.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
    });
}
export function calculateScoreToPar(score, par) {
    const diff = score - par;
    if (diff === 0)
        return "E";
    return diff > 0 ? `+${diff}` : `${diff}`;
}
// Distance calculation using Haversine formula (for GPS)
export function calculateDistance(lat1, lon1, lat2, lon2, unit = 'yards') {
    const R = unit === 'yards' ? 6967410 : 6371000; // Earth radius in yards or meters
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c);
}
function toRad(deg) {
    return deg * (Math.PI / 180);
}
// Weather-adjusted "plays like" distance
export function calculatePlaysLikeDistance(actualDistance, temperature, // Fahrenheit
altitude, // feet
windSpeed, // mph
windDirection) {
    let adjusted = actualDistance;
    // Temperature adjustment (~1 yard per 10°F from 70°F baseline)
    const tempDiff = temperature - 70;
    adjusted += tempDiff * 0.1;
    // Altitude adjustment (~2% per 1000 feet)
    adjusted -= (altitude / 1000) * actualDistance * 0.02;
    // Wind adjustment (~1 yard per 1 mph)
    if (windDirection === 'headwind') {
        adjusted += windSpeed;
    }
    else if (windDirection === 'tailwind') {
        adjusted -= windSpeed * 0.5; // Tailwind helps less than headwind hurts
    }
    // Crosswind has minimal distance effect
    return Math.round(adjusted);
}
