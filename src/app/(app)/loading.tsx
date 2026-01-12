export default function Loading() {
  return (
    <div className="min-h-[400px] flex items-center justify-center">
      <div className="flex flex-col items-center gap-4">
        <div className="relative w-16 h-16">
          <div className="absolute inset-0 rounded-full border-4 border-background-tertiary"></div>
          <div className="absolute inset-0 rounded-full border-4 border-accent-green border-t-transparent animate-spin"></div>
        </div>
        <p className="text-foreground-muted text-sm">Loading...</p>
      </div>
    </div>
  );
}

