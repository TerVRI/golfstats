'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check } from 'lucide-react';

const plans = [
  {
    id: 'monthly',
    name: 'Monthly',
    price: '$9.99',
    interval: 'month',
    priceId: process.env.NEXT_PUBLIC_STRIPE_MONTHLY_PRICE_ID,
    features: [
      'Unlimited round tracking',
      'Strokes gained analytics',
      'Course visualizations',
      'Trend analysis',
      'Export data',
    ],
  },
  {
    id: 'annual',
    name: 'Annual',
    price: '$59.99',
    interval: 'year',
    priceId: process.env.NEXT_PUBLIC_STRIPE_ANNUAL_PRICE_ID,
    popular: true,
    savings: 'Save 50%',
    features: [
      'Everything in Monthly',
      'Priority support',
      'Early access to new features',
      'Annual review report',
    ],
  },
];

const freeFeatures = [
  'Track up to 5 rounds',
  'Basic statistics',
  'Course search',
  'Score entry',
];

export default function PricingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSubscribe = async (priceId: string, planId: string) => {
    setLoading(planId);
    setError(null);

    try {
      const response = await fetch('/api/stripe/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceId }),
      });

      const data = await response.json();

      if (data.url) {
        window.location.href = data.url;
      } else {
        setError(data.error || 'Failed to create checkout session');
      }
    } catch (err) {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 py-12 px-4">
      <div className="max-w-5xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-4">
            Upgrade to Pro
          </h1>
          <p className="text-xl text-gray-600 dark:text-gray-400">
            Get tour-level analytics and unlock your full potential
          </p>
        </div>

        {error && (
          <div className="max-w-md mx-auto mb-8 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-red-700 dark:text-red-400 text-center">
            {error}
          </div>
        )}

        {/* Pricing Cards */}
        <div className="grid md:grid-cols-3 gap-8">
          {/* Free Tier */}
          <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg p-8 border border-gray-200 dark:border-gray-700">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
              Free
            </h3>
            <div className="mb-6">
              <span className="text-4xl font-bold text-gray-900 dark:text-white">$0</span>
              <span className="text-gray-500 dark:text-gray-400">/forever</span>
            </div>
            <ul className="space-y-3 mb-8">
              {freeFeatures.map((feature) => (
                <li key={feature} className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                  <Check className="h-5 w-5 text-green-500" />
                  {feature}
                </li>
              ))}
            </ul>
            <button
              onClick={() => router.push('/dashboard')}
              className="w-full py-3 px-4 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-medium hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Current Plan
            </button>
          </div>

          {/* Paid Plans */}
          {plans.map((plan) => (
            <div
              key={plan.id}
              className={`bg-white dark:bg-gray-800 rounded-2xl shadow-lg p-8 relative ${
                plan.popular
                  ? 'border-2 border-green-500 ring-4 ring-green-500/20'
                  : 'border border-gray-200 dark:border-gray-700'
              }`}
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                  <span className="bg-green-500 text-white text-sm font-medium px-4 py-1 rounded-full">
                    Most Popular
                  </span>
                </div>
              )}
              
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                {plan.name}
              </h3>
              
              <div className="mb-2">
                <span className="text-4xl font-bold text-gray-900 dark:text-white">
                  {plan.price}
                </span>
                <span className="text-gray-500 dark:text-gray-400">/{plan.interval}</span>
              </div>
              
              {plan.savings && (
                <p className="text-green-600 dark:text-green-400 text-sm font-medium mb-6">
                  {plan.savings}
                </p>
              )}
              
              <ul className="space-y-3 mb-8">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-2 text-gray-600 dark:text-gray-400">
                    <Check className="h-5 w-5 text-green-500" />
                    {feature}
                  </li>
                ))}
              </ul>
              
              <button
                onClick={() => plan.priceId && handleSubscribe(plan.priceId, plan.id)}
                disabled={loading === plan.id || !plan.priceId}
                className={`w-full py-3 px-4 rounded-lg font-medium transition-colors ${
                  plan.popular
                    ? 'bg-green-600 hover:bg-green-700 text-white'
                    : 'bg-gray-900 dark:bg-white hover:bg-gray-800 dark:hover:bg-gray-100 text-white dark:text-gray-900'
                } disabled:opacity-50 disabled:cursor-not-allowed`}
              >
                {loading === plan.id ? 'Loading...' : 'Start 14-Day Free Trial'}
              </button>
            </div>
          ))}
        </div>

        {/* FAQ / Trust */}
        <div className="mt-16 text-center">
          <p className="text-gray-500 dark:text-gray-400 text-sm">
            14-day free trial on all plans. Cancel anytime. No questions asked.
          </p>
          <p className="text-gray-500 dark:text-gray-400 text-sm mt-2">
            Secure payment powered by Stripe. Your card details are never stored on our servers.
          </p>
        </div>
      </div>
    </div>
  );
}
