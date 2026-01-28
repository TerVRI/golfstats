export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-background py-20">
      <div className="max-w-3xl mx-auto px-4">
        <h1 className="text-3xl font-bold text-foreground mb-8">Privacy Policy</h1>
        
        <div className="prose prose-invert max-w-none space-y-6">
          <p className="text-foreground-muted">Last updated: January 2026</p>
          
          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">1. Information We Collect</h2>
            <p className="text-foreground-muted">
              RoundCaddy collects information you provide directly to us, including:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>Account information (email, name)</li>
              <li>Golf round data (scores, courses played, statistics)</li>
              <li>Device information for app functionality</li>
              <li>Location data (only when you choose to use GPS features)</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">2. How We Use Your Information</h2>
            <p className="text-foreground-muted">
              We use the information we collect to:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>Provide, maintain, and improve our services</li>
              <li>Calculate your strokes gained statistics</li>
              <li>Send you updates about your account and our services</li>
              <li>Respond to your comments, questions, and requests</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">3. Data Security</h2>
            <p className="text-foreground-muted">
              We take reasonable measures to help protect your personal information from loss, 
              theft, misuse, unauthorized access, disclosure, alteration, and destruction. 
              Your data is encrypted in transit and at rest.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">4. Data Sharing</h2>
            <p className="text-foreground-muted">
              We do not sell your personal information. We may share your information only in 
              the following circumstances:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>With your consent</li>
              <li>To comply with legal obligations</li>
              <li>With service providers who assist in our operations</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">5. Your Rights</h2>
            <p className="text-foreground-muted">
              You have the right to:
            </p>
            <ul className="list-disc pl-6 text-foreground-muted space-y-2 mt-4">
              <li>Access your personal data</li>
              <li>Correct inaccurate data</li>
              <li>Delete your account and associated data</li>
              <li>Export your data in a portable format</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-foreground mt-8 mb-4">6. Contact Us</h2>
            <p className="text-foreground-muted">
              If you have any questions about this Privacy Policy, please contact us at:{' '}
              <a href="mailto:privacy@roundcaddy.com" className="text-accent-green hover:underline">
                privacy@roundcaddy.com
              </a>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
