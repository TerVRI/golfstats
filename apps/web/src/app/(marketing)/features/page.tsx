import Link from 'next/link';
import { 
  Target, 
  TrendingUp, 
  BarChart3, 
  Zap,
  Smartphone,
  Watch,
  Cloud,
  Users,
  Map,
  Award,
  ArrowRight,
  Check
} from 'lucide-react';
import { Button } from '@/components/ui';

const mainFeatures = [
  {
    icon: TrendingUp,
    title: 'Strokes Gained Analytics',
    description: 'The same statistical framework used by PGA Tour professionals. See exactly where you\'re gaining and losing strokes compared to tour benchmarks.',
    benefits: [
      'SG: Off the Tee - Analyze your driving performance',
      'SG: Approach - Track your iron play accuracy',
      'SG: Around Green - Measure your short game',
      'SG: Putting - Understand putting from all distances',
    ],
  },
  {
    icon: BarChart3,
    title: 'Detailed Round Tracking',
    description: 'Log every shot or keep it simple with just the basics. Our flexible input system adapts to how much detail you want to track.',
    benefits: [
      'Hole-by-hole scoring',
      'Fairways hit and GIR tracking',
      'Putts per hole and total',
      'Optional shot-by-shot tracking',
    ],
  },
  {
    icon: Map,
    title: 'Course Visualization',
    description: 'View detailed course maps with hole layouts, hazards, and greens. Know exactly what you\'re facing before your round.',
    benefits: [
      '23,000+ courses worldwide',
      'Hole layouts with hazards',
      'Green and fairway shapes',
      'Tee box positions',
    ],
  },
  {
    icon: Target,
    title: 'AI-Powered Insights',
    description: 'Get personalized recommendations on where to focus your practice based on your actual performance data.',
    benefits: [
      'Identify weaknesses automatically',
      'Practice recommendations',
      'Progress tracking over time',
      'Comparison to handicap peers',
    ],
  },
];

const additionalFeatures = [
  { icon: Smartphone, title: 'iOS & Web Apps', description: 'Track rounds on your iPhone or any web browser' },
  { icon: Watch, title: 'Apple Watch', description: 'Quick score entry and live distances on your wrist' },
  { icon: Cloud, title: 'Cloud Sync', description: 'Your data is always backed up and synced across devices' },
  { icon: Users, title: 'Compare with Friends', description: 'See how you stack up against others in your group' },
  { icon: Award, title: 'Achievements', description: 'Earn badges and track milestones in your golf journey' },
  { icon: Zap, title: 'Fast Entry', description: 'Log a round in under 5 minutes with our streamlined interface' },
];

export default function FeaturesPage() {
  return (
    <div className="min-h-screen bg-background">
      {/* Hero */}
      <div className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-accent-green/5 via-background to-accent-blue/5" />
        <div className="relative max-w-6xl mx-auto px-4 py-20 text-center">
          <h1 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            Tour-Level Analytics for
            <br />
            <span className="gradient-text">Every Golfer</span>
          </h1>
          <p className="text-lg text-foreground-muted max-w-2xl mx-auto mb-8">
            Stop guessing where to improve. RoundCaddy gives you the same strokes gained 
            analysis used by PGA Tour professionals to identify exactly where you&apos;re 
            gaining and losing shots.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link href="/dashboard">
              <Button size="lg" className="text-base px-8">
                Start Free Trial
                <ArrowRight className="w-5 h-5 ml-2" />
              </Button>
            </Link>
            <Link href="/pricing">
              <Button variant="secondary" size="lg" className="text-base px-8">
                View Pricing
              </Button>
            </Link>
          </div>
        </div>
      </div>

      {/* Main Features */}
      <div className="max-w-6xl mx-auto px-4 py-20">
        <div className="space-y-24">
          {mainFeatures.map((feature, index) => (
            <div
              key={feature.title}
              className={`flex flex-col ${
                index % 2 === 0 ? 'lg:flex-row' : 'lg:flex-row-reverse'
              } items-center gap-12`}
            >
              <div className="flex-1">
                <div className="w-14 h-14 rounded-xl bg-accent-green/10 flex items-center justify-center mb-6">
                  <feature.icon className="w-8 h-8 text-accent-green" />
                </div>
                <h2 className="text-3xl font-bold text-foreground mb-4">{feature.title}</h2>
                <p className="text-lg text-foreground-muted mb-6">{feature.description}</p>
                <ul className="space-y-3">
                  {feature.benefits.map((benefit) => (
                    <li key={benefit} className="flex items-center gap-3 text-foreground-muted">
                      <Check className="w-5 h-5 text-accent-green shrink-0" />
                      {benefit}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="flex-1">
                <div className="aspect-video bg-gradient-to-br from-accent-green/10 to-accent-blue/10 rounded-2xl border border-card-border flex items-center justify-center">
                  <feature.icon className="w-24 h-24 text-accent-green/30" />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Additional Features Grid */}
      <div className="bg-background-secondary py-20">
        <div className="max-w-6xl mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-foreground mb-4">And Much More</h2>
            <p className="text-foreground-muted max-w-2xl mx-auto">
              Everything you need to track, analyze, and improve your golf game.
            </p>
          </div>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {additionalFeatures.map((feature) => (
              <div
                key={feature.title}
                className="p-6 rounded-xl bg-card-background border border-card-border"
              >
                <div className="w-10 h-10 rounded-lg bg-accent-green/10 flex items-center justify-center mb-4">
                  <feature.icon className="w-5 h-5 text-accent-green" />
                </div>
                <h3 className="font-semibold text-foreground mb-2">{feature.title}</h3>
                <p className="text-sm text-foreground-muted">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* CTA */}
      <div className="max-w-6xl mx-auto px-4 py-20">
        <div className="bg-gradient-to-br from-accent-green/10 to-accent-blue/10 rounded-2xl p-8 md:p-12 text-center">
          <h2 className="text-2xl md:text-3xl font-bold text-foreground mb-4">
            Ready to Improve Your Game?
          </h2>
          <p className="text-foreground-muted max-w-xl mx-auto mb-8">
            Join thousands of golfers using data to take their game to the next level. 
            Start your 14-day free trial today.
          </p>
          <Link href="/dashboard">
            <Button size="lg" className="text-base px-8">
              Get Started Free
              <ArrowRight className="w-5 h-5 ml-2" />
            </Button>
          </Link>
        </div>
      </div>
    </div>
  );
}
