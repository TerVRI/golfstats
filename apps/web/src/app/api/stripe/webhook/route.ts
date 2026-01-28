import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

// Use service role for webhook (no user context)
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(request: NextRequest) {
  const body = await request.text();
  const signature = request.headers.get('stripe-signature');

  if (!signature) {
    return NextResponse.json({ error: 'No signature' }, { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  console.log(`📩 Stripe webhook: ${event.type}`);

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutCompleted(session);
        break;
      }

      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionUpdate(subscription);
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionCancelled(subscription);
        break;
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice;
        await handlePaymentSucceeded(invoice);
        break;
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice;
        await handlePaymentFailed(invoice);
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  } catch (error) {
    console.error('Webhook handler error:', error);
    return NextResponse.json({ error: 'Webhook handler failed' }, { status: 500 });
  }

  return NextResponse.json({ received: true });
}

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const userId = session.metadata?.supabase_user_id;
  if (!userId) {
    console.error('No user ID in checkout session metadata');
    return;
  }

  console.log(`✅ Checkout completed for user ${userId}`);
  
  // Subscription will be created/updated via subscription events
}

async function handleSubscriptionUpdate(subscription: Stripe.Subscription) {
  const userId = subscription.metadata?.supabase_user_id;
  if (!userId) {
    // Try to get user ID from customer
    const customer = await stripe.customers.retrieve(subscription.customer as string);
    if ('metadata' in customer && customer.metadata?.supabase_user_id) {
      await upsertSubscription(customer.metadata.supabase_user_id, subscription);
    } else {
      console.error('Could not find user ID for subscription');
    }
    return;
  }

  await upsertSubscription(userId, subscription);
}

async function upsertSubscription(userId: string, subscription: Stripe.Subscription) {
  const priceId = subscription.items.data[0]?.price.id;
  const plan = priceId?.includes('annual') ? 'annual' : 'monthly';
  
  let status: string;
  switch (subscription.status) {
    case 'active':
      status = 'active';
      break;
    case 'trialing':
      status = 'trialing';
      break;
    case 'past_due':
      status = 'past_due';
      break;
    case 'canceled':
    case 'unpaid':
      status = 'cancelled';
      break;
    default:
      status = 'expired';
  }

  const { error } = await supabase
    .from('subscriptions')
    .upsert({
      user_id: userId,
      source: 'stripe',
      plan,
      status,
      stripe_subscription_id: subscription.id,
      stripe_customer_id: subscription.customer as string,
      price_cents: subscription.items.data[0]?.price.unit_amount,
      currency: subscription.currency.toUpperCase(),
      current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
      current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
      trial_end: subscription.trial_end 
        ? new Date(subscription.trial_end * 1000).toISOString() 
        : null,
      cancelled_at: subscription.canceled_at 
        ? new Date(subscription.canceled_at * 1000).toISOString() 
        : null,
    }, {
      onConflict: 'stripe_subscription_id',
    });

  if (error) {
    console.error('Error upserting subscription:', error);
    throw error;
  }

  console.log(`✅ Subscription ${subscription.id} upserted for user ${userId}`);

  // Update profile subscription tier
  await supabase
    .from('profiles')
    .update({ subscription_tier: status === 'active' || status === 'trialing' ? 'pro' : 'free' })
    .eq('id', userId);
}

async function handleSubscriptionCancelled(subscription: Stripe.Subscription) {
  const { error } = await supabase
    .from('subscriptions')
    .update({
      status: 'cancelled',
      cancelled_at: new Date().toISOString(),
    })
    .eq('stripe_subscription_id', subscription.id);

  if (error) {
    console.error('Error cancelling subscription:', error);
    throw error;
  }

  console.log(`❌ Subscription ${subscription.id} cancelled`);

  // Update profile
  const userId = subscription.metadata?.supabase_user_id;
  if (userId) {
    await supabase
      .from('profiles')
      .update({ subscription_tier: 'free' })
      .eq('id', userId);
  }
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  console.log(`💳 Payment succeeded for invoice ${invoice.id}`);
  // Subscription status is handled by subscription.updated event
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  console.log(`⚠️ Payment failed for invoice ${invoice.id}`);
  
  // Update subscription status to past_due
  if (invoice.subscription) {
    await supabase
      .from('subscriptions')
      .update({ status: 'past_due' })
      .eq('stripe_subscription_id', invoice.subscription as string);
  }
}
