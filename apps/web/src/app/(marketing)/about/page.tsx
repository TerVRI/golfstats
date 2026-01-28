import Link from 'next/link';
import { Target, ArrowRight, Heart, Globe, Zap } from 'lucide-react';
import { Button } from '@/components/ui';

export default function AboutPage() {
  return (
    <div className="min-h-screen bg-background">
      {/* Hero */}
      <div className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-accent-green/5 via-background to-accent-blue/5" />
        <div className="relative max-w-4xl mx-auto px-4 py-20 text-center">
          <h1 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            About RoundCaddy
          </h1>
          <p className="text-lg text-foreground-muted max-w-2xl mx-auto">
            We&apos;re on a mission to bring tour-level analytics to every golfer, 
            helping you understand your game and improve faster than ever before.
          </p>
        </div>
      </div>

      {/* Story */}
      <div className="max-w-4xl mx-auto px-4 py-16">
        <div className="prose prose-lg prose-invert max-w-none">
          <h2 className="text-2xl font-bold text-foreground mb-6">Our Story</h2>
          <p className="text-foreground-muted mb-6">
            RoundCaddy was born from a simple frustration: why do professional golfers have 
            access to incredible statistics and analysis tools, while amateur golfers are 
            left guessing about where to improve?
          </p>
          <p className="text-foreground-muted mb-6">
            The concept of &quot;Strokes Gained&quot; revolutionized how the PGA Tour analyzes 
            player performance. By comparing each shot to a baseline, it becomes crystal 
            clear where a player is excelling and where they&apos;re leaving shots on the table.
          </p>
          <p className="text-foreground-muted mb-6">
            We built RoundCaddy to bring this same powerful analysis to every golfer. 
            Whether you&apos;re a scratch player or just starting out, understanding your 
            strokes gained can transform how you practice and play.
          </p>
        </div>
      </div>

      {/* Values */}
      <div className="bg-background-secondary py-16">
        <div className="max-w-6xl mx-auto px-4">
          <h2 className="text-2xl font-bold text-foreground text-center mb-12">Our Values</h2>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="w-14 h-14 rounded-xl bg-accent-green/10 flex items-center justify-center mx-auto mb-4">
                <Zap className="w-7 h-7 text-accent-green" />
              </div>
              <h3 className="font-semibold text-foreground mb-2">Simplicity</h3>
              <p className="text-foreground-muted">
                Powerful analytics shouldn&apos;t be complicated. We make it easy to track 
                your rounds and understand your data.
              </p>
            </div>
            <div className="text-center">
              <div className="w-14 h-14 rounded-xl bg-accent-green/10 flex items-center justify-center mx-auto mb-4">
                <Globe className="w-7 h-7 text-accent-green" />
              </div>
              <h3 className="font-semibold text-foreground mb-2">Accessibility</h3>
              <p className="text-foreground-muted">
                Every golfer deserves access to great tools, regardless of skill level 
                or budget.
              </p>
            </div>
            <div className="text-center">
              <div className="w-14 h-14 rounded-xl bg-accent-green/10 flex items-center justify-center mx-auto mb-4">
                <Heart className="w-7 h-7 text-accent-green" />
              </div>
              <h3 className="font-semibold text-foreground mb-2">Passion</h3>
              <p className="text-foreground-muted">
                We&apos;re golfers too. We build the tools we wish we had when 
                we started tracking our game.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="max-w-6xl mx-auto px-4 py-16">
        <div className="grid md:grid-cols-4 gap-8 text-center">
          <div>
            <p className="text-4xl font-bold text-accent-green mb-2">23,000+</p>
            <p className="text-foreground-muted">Golf Courses</p>
          </div>
          <div>
            <p className="text-4xl font-bold text-accent-green mb-2">100K+</p>
            <p className="text-foreground-muted">Rounds Tracked</p>
          </div>
          <div>
            <p className="text-4xl font-bold text-accent-green mb-2">50+</p>
            <p className="text-foreground-muted">Countries</p>
          </div>
          <div>
            <p className="text-4xl font-bold text-accent-green mb-2">4.8★</p>
            <p className="text-foreground-muted">App Store Rating</p>
          </div>
        </div>
      </div>

      {/* Team */}
      <div className="bg-background-secondary py-16">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <h2 className="text-2xl font-bold text-foreground mb-6">Built by Golfers</h2>
          <p className="text-foreground-muted mb-8 max-w-2xl mx-auto">
            RoundCaddy is built by a small team of passionate golfers and engineers 
            who believe that data can help anyone play better golf.
          </p>
          <div className="flex justify-center">
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
              <Target className="w-10 h-10 text-white" />
            </div>
          </div>
        </div>
      </div>

      {/* Contact */}
      <div className="max-w-4xl mx-auto px-4 py-16">
        <div className="bg-card-background border border-card-border rounded-2xl p-8 md:p-12">
          <h2 className="text-2xl font-bold text-foreground mb-4 text-center">Get in Touch</h2>
          <p className="text-foreground-muted text-center mb-8">
            Have questions, feedback, or just want to chat about golf? We&apos;d love to hear from you.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a href="mailto:hello@roundcaddy.com">
              <Button variant="secondary" className="text-base px-8">
                Email Us
              </Button>
            </a>
            <a href="https://twitter.com/roundcaddy" target="_blank" rel="noopener noreferrer">
              <Button variant="secondary" className="text-base px-8">
                Follow on X
              </Button>
            </a>
          </div>
        </div>
      </div>

      {/* CTA */}
      <div className="max-w-4xl mx-auto px-4 pb-20">
        <div className="bg-gradient-to-br from-accent-green/10 to-accent-blue/10 rounded-2xl p-8 md:p-12 text-center">
          <h2 className="text-2xl md:text-3xl font-bold text-foreground mb-4">
            Ready to Improve Your Game?
          </h2>
          <p className="text-foreground-muted max-w-xl mx-auto mb-8">
            Join thousands of golfers using RoundCaddy to track, analyze, and improve.
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
