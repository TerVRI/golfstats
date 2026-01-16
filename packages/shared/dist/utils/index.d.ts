export declare function formatNumber(num: number, decimals?: number): string;
export declare function formatSG(value: number): string;
export declare function formatDate(date: Date | string): string;
export declare function formatDateShort(date: Date | string): string;
export declare function calculateScoreToPar(score: number, par: number): string;
export declare function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number, unit?: 'yards' | 'meters'): number;
export declare function calculatePlaysLikeDistance(actualDistance: number, temperature: number, // Fahrenheit
altitude: number, // feet
windSpeed: number, // mph
windDirection: 'headwind' | 'tailwind' | 'crosswind'): number;
//# sourceMappingURL=index.d.ts.map