export interface WeatherData {
    temperature: number;
    windSpeed: number;
    windDirection: number;
    windDirectionLabel: string;
    precipitation: number;
    precipitationProbability: number;
    humidity: number;
    uvIndex: number;
    conditions: string;
    icon: string;
    isGoodForGolf: boolean;
}
export interface WeatherForecast {
    current: WeatherData;
    hourly: (WeatherData & {
        time: string;
    })[];
    daily: {
        date: string;
        tempHigh: number;
        tempLow: number;
        conditions: string;
        icon: string;
        precipitationProbability: number;
    }[];
}
export declare function fetchWeather(latitude: number, longitude: number): Promise<WeatherForecast | null>;
export declare function getWindImpact(windSpeed: number, windDirection: number, shotDirection: number): 'headwind' | 'tailwind' | 'crosswind';
//# sourceMappingURL=index.d.ts.map