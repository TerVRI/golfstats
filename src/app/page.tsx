import Link from "next/link";
import { Button } from "@/components/ui";
import { Target, TrendingUp, BarChart3, Zap, ArrowRight, CheckCircle } from "lucide-react";

export default function Home() {
  return (
    <div className="min-h-screen bg-background">
      {/* Hero Section */}
      <div className="relative overflow-hidden">
        {/* Background gradient */}
        <div className="absolute inset-0 bg-gradient-to-br from-accent-green/5 via-background to-accent-blue/5" />
        <div className="absolute top-20 left-1/4 w-96 h-96 bg-accent-green/10 rounded-full blur-3xl" />
        <div className="absolute bottom-20 right-1/4 w-96 h-96 bg-accent-blue/10 rounded-full blur-3xl" />
        
        <div className="relative max-w-6xl mx-auto px-4 py-20 md:py-32">
          <div className="text-center space-y-6 animate-fade-in">
            {/* Logo */}
            <div className="flex justify-center mb-8">
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
                <Target className="w-10 h-10 text-white" />
              </div>
            </div>
            
            <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold text-foreground tracking-tight">
              <span className="gradient-text">Strokes Gained</span>
              <br />
              <span className="text-foreground">Analytics</span>
          </h1>
            
            <p className="text-lg md:text-xl text-foreground-muted max-w-2xl mx-auto">
              The same tour-level statistics used by PGA professionals, now available for every golfer. 
              Discover exactly where you&apos;re gaining and losing strokes.
            </p>
            
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
              <Link href="/dashboard">
                <Button size="lg" className="text-base px-8 py-4">
                  Go to Dashboard
                  <ArrowRight className="w-5 h-5 ml-2" />
                </Button>
              </Link>
              <Link href="/rounds/new">
                <Button variant="secondary" size="lg" className="text-base px-8 py-4">
                  Log Your First Round
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div className="max-w-6xl mx-auto px-4 py-20">
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            Know Your Game Inside Out
          </h2>
          <p className="text-foreground-muted max-w-2xl mx-auto">
            Stop guessing where to practice. Our strokes gained analysis shows you exactly 
            where you&apos;re losing shots compared to better players.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          <FeatureCard
            icon={TrendingUp}
            title="SG: Off the Tee"
            description="Analyze your driving performance including distance and accuracy off the tee on par 4s and 5s."
          />
          <FeatureCard
            icon={Target}
            title="SG: Approach"
            description="Track your iron play and see how well you hit greens compared to tour benchmarks."
          />
          <FeatureCard
            icon={Zap}
            title="SG: Around Green"
            description="Measure your short game including chips, pitches, and bunker shots."
          />
          <FeatureCard
            icon={BarChart3}
            title="SG: Putting"
            description="Understand your putting from various distances and identify where to improve."
          />
        </div>
      </div>

      {/* How It Works */}
      <div className="bg-background-secondary py-20">
        <div className="max-w-6xl mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
              How It Works
            </h2>
            <p className="text-foreground-muted max-w-2xl mx-auto">
              Getting started is easy. Log your rounds and let our engine do the analysis.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <StepCard
              step={1}
              title="Log Your Round"
              description="Enter your scores hole-by-hole with simple inputs for putts, fairways hit, and greens in regulation."
            />
            <StepCard
              step={2}
              title="Automatic Analysis"
              description="Our strokes gained engine calculates your performance against PGA Tour benchmarks."
            />
            <StepCard
              step={3}
              title="Get Insights"
              description="See exactly where you're gaining and losing strokes, and get personalized practice recommendations."
            />
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="max-w-6xl mx-auto px-4 py-20">
        <div className="bg-gradient-to-br from-accent-green/10 to-accent-blue/10 rounded-2xl p-8 md:p-12 text-center">
          <h2 className="text-2xl md:text-3xl font-bold text-foreground mb-4">
            Ready to Improve Your Game?
          </h2>
          <p className="text-foreground-muted max-w-xl mx-auto mb-8">
            Join golfers who are using data to take their game to the next level.
          </p>
          <div className="flex flex-wrap justify-center gap-4 mb-8">
            <BenefitBadge text="Free to use" />
            <BenefitBadge text="No equipment needed" />
            <BenefitBadge text="Tour-level analytics" />
          </div>
          <Link href="/rounds/new">
            <Button size="lg" className="text-base px-8">
              Start Tracking Now
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </Link>
        </div>
      </div>

      {/* Footer */}
      <footer className="border-t border-card-border py-8">
        <div className="max-w-6xl mx-auto px-4 text-center">
          <div className="flex items-center justify-center gap-2 mb-4">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
              <Target className="w-5 h-5 text-white" />
            </div>
            <span className="font-bold text-foreground">GolfStats</span>
          </div>
          <p className="text-sm text-foreground-muted">
            Tour-level strokes gained analytics for every golfer
          </p>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ 
  icon: Icon, 
  title, 
  description 
}: { 
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
}) {
  return (
    <div className="p-6 rounded-xl bg-card-background border border-card-border hover:border-accent-green/30 transition-colors">
      <div className="w-12 h-12 rounded-lg bg-accent-green/10 flex items-center justify-center mb-4">
        <Icon className="w-6 h-6 text-accent-green" />
      </div>
      <h3 className="font-semibold text-foreground mb-2">{title}</h3>
      <p className="text-sm text-foreground-muted">{description}</p>
    </div>
  );
}

function StepCard({ 
  step, 
  title, 
  description 
}: { 
  step: number;
  title: string;
  description: string;
}) {
  return (
    <div className="text-center">
      <div className="w-12 h-12 rounded-full bg-accent-green text-white font-bold text-xl flex items-center justify-center mx-auto mb-4">
        {step}
      </div>
      <h3 className="font-semibold text-foreground mb-2">{title}</h3>
      <p className="text-sm text-foreground-muted">{description}</p>
    </div>
  );
}

function BenefitBadge({ text }: { text: string }) {
  return (
    <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-background-secondary border border-card-border">
      <CheckCircle className="w-4 h-4 text-accent-green" />
      <span className="text-sm text-foreground">{text}</span>
    </div>
  );
}
