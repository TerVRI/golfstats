"use client";

import { Target, WifiOff } from "lucide-react";

export default function OfflinePage() {
  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="text-center max-w-md">
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
            <Target className="w-10 h-10 text-white" />
          </div>
        </div>
        
        <div className="flex justify-center mb-4">
          <WifiOff className="w-12 h-12 text-foreground-muted" />
        </div>
        
        <h1 className="text-2xl font-bold text-foreground mb-2">
          You&apos;re Offline
        </h1>
        
        <p className="text-foreground-muted mb-6">
          It looks like you&apos;ve lost your internet connection. 
          Check your connection and try again.
        </p>
        
        <button
          onClick={() => window.location.reload()}
          className="px-6 py-3 bg-accent-green text-white rounded-xl font-medium hover:bg-accent-green/90 transition-colors"
        >
          Try Again
        </button>
        
        <p className="text-sm text-foreground-muted mt-8">
          RoundCaddy works best with an internet connection to sync your rounds and stats.
        </p>
      </div>
    </div>
  );
}
