export default function TermsPage() {
  return (
    <div className="min-h-screen bg-background py-20">
      <div className="max-w-3xl mx-auto px-4">
        <h1 className="text-3xl font-bold text-foreground mb-8">Terms of Service</h1>
        
        <div className="prose prose-invert max-w-none space-y-6">
          <p className="text-foreground-muted">Last updated: January 2026</p>
          
          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">1. Acceptance of Terms</h2>
            <p className="text-foreground-muted">
              By accessing or using RoundCaddy, you agree to be bound by these Terms of Service 
              and all applicable laws and regulations. If you do not agree with any of these 
              terms, you are prohibited from using this service.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">2. Description of Service</h2>
            <p className="text-foreground-muted">
              RoundCaddy is a golf statistics tracking and analysis platform that provides:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>Round tracking and scoring</li>
              <li>Strokes gained analysis</li>
              <li>Course information and visualization</li>
              <li>Performance trends and insights</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">3. User Accounts</h2>
            <p className="text-foreground-muted">
              You are responsible for maintaining the confidentiality of your account and 
              password. You agree to accept responsibility for all activities that occur 
              under your account.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">4. Subscription and Billing</h2>
            <p className="text-foreground-muted">
              Some features require a paid subscription. By subscribing, you agree to:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>Pay the applicable subscription fees</li>
              <li>Automatic renewal unless cancelled before the renewal date</li>
              <li>No refunds for partial subscription periods</li>
            </ul>
            <p className="text-foreground-muted mt-4">
              You can cancel your subscription at any time through your account settings or 
              the App Store/Google Play.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">5. User Content</h2>
            <p className="text-foreground-muted">
              You retain ownership of any content you submit to RoundCaddy. By submitting 
              content, you grant us a license to use, store, and display that content as 
              necessary to provide our services.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">6. Prohibited Uses</h2>
            <p className="text-foreground-muted">
              You may not use RoundCaddy to:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>Violate any applicable laws or regulations</li>
              <li>Infringe on the rights of others</li>
              <li>Attempt to gain unauthorized access to our systems</li>
              <li>Interfere with the proper functioning of the service</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">7. Disclaimer of Warranties</h2>
            <p className="text-foreground-muted">
              RoundCaddy is provided &quot;as is&quot; without warranties of any kind. We do not 
              guarantee that the service will be uninterrupted, secure, or error-free.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">8. Limitation of Liability</h2>
            <p className="text-foreground-muted">
              In no event shall RoundCaddy be liable for any indirect, incidental, special, 
              consequential, or punitive damages arising out of or relating to your use of 
              the service.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">9. Changes to Terms</h2>
            <p className="text-foreground-muted">
              We reserve the right to modify these terms at any time. We will notify users 
              of any material changes via email or through the app.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">10. Contact</h2>
            <p className="text-foreground-muted">
              For any questions about these Terms, please contact us at:{' '}
              <a href="mailto:legal@roundcaddy.com" className="text-accent-green hover:underline">
                legal@roundcaddy.com
              </a>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
