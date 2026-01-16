"use client";

import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui";
import { Target, Mail, Eye, EyeOff } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type AuthMode = "signin" | "signup" | "forgot";

export default function LoginPage() {
  const router = useRouter();
  const [loading, setLoading] = useState<string | null>(null);
  const [checkingAuth, setCheckingAuth] = useState(true);
  const [authMode, setAuthMode] = useState<AuthMode>("signin");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  
  // Form state
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");

  useEffect(() => {
    const supabase = createClient();
    
    // Check if already logged in
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) {
        router.push("/dashboard");
      } else {
        setCheckingAuth(false);
      }
    });
  }, [router]);

  const handleGoogleLogin = async () => {
    setLoading("google");
    setError(null);
    const supabase = createClient();
    
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) {
      console.error("Login error:", error);
      setError(error.message);
      setLoading(null);
    }
  };

  const handleAppleLogin = async () => {
    setLoading("apple");
    setError(null);
    const supabase = createClient();
    
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "apple",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) {
      console.error("Apple login error:", error);
      setError(error.message);
      setLoading(null);
    }
  };

  const handleEmailSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading("email");
    setError(null);
    const supabase = createClient();

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setLoading(null);
    } else {
      router.push("/dashboard");
    }
  };

  const handleEmailSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading("email");
    setError(null);
    const supabase = createClient();

    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
        data: {
          full_name: fullName,
        },
      },
    });

    if (error) {
      setError(error.message);
      setLoading(null);
    } else {
      setSuccess("Check your email for a confirmation link!");
      setLoading(null);
    }
  };

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading("email");
    setError(null);
    const supabase = createClient();

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/profile`,
    });

    if (error) {
      setError(error.message);
      setLoading(null);
    } else {
      setSuccess("Check your email for a password reset link!");
      setLoading(null);
    }
  };

  if (checkingAuth) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-accent-green border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      {/* Background effects */}
      <div className="absolute inset-0 bg-gradient-to-br from-accent-green/5 via-background to-accent-blue/5" />
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-accent-green/10 rounded-full blur-3xl" />
      <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-accent-blue/10 rounded-full blur-3xl" />

      <div className="relative w-full max-w-md">
        <div className="bg-card-background border border-card-border rounded-2xl p-8 shadow-2xl">
          {/* Logo */}
          <div className="flex justify-center mb-6">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-accent-green to-accent-blue flex items-center justify-center">
              <Target className="w-10 h-10 text-white" />
            </div>
          </div>

          {/* Title */}
          <div className="text-center mb-6">
            <h1 className="text-2xl font-bold text-foreground mb-2">
              {authMode === "signin" && "Welcome to RoundCaddy"}
              {authMode === "signup" && "Create Account"}
              {authMode === "forgot" && "Reset Password"}
            </h1>
            <p className="text-foreground-muted text-sm">
              {authMode === "signin" && "Sign in to track your rounds and analyze your game"}
              {authMode === "signup" && "Start your journey to better golf"}
              {authMode === "forgot" && "Enter your email to receive a reset link"}
            </p>
          </div>

          {/* Error/Success Messages */}
          {error && (
            <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              {error}
            </div>
          )}
          {success && (
            <div className="mb-4 p-3 rounded-lg bg-green-500/10 border border-green-500/20 text-green-400 text-sm">
              {success}
            </div>
          )}

          {/* Auth Mode: Sign In or Sign Up */}
          {authMode !== "forgot" && (
            <>
              {/* Social Sign In Buttons */}
              <div className="space-y-3 mb-6">
                {/* Sign in with Apple */}
                <Button
                  onClick={handleAppleLogin}
                  disabled={loading !== null}
                  className="w-full bg-black hover:bg-gray-900 text-white py-3"
                  size="lg"
                >
                  {loading === "apple" ? (
                    <div className="animate-spin w-5 h-5 border-2 border-white border-t-transparent rounded-full mr-3" />
                  ) : (
                    <svg className="w-5 h-5 mr-3" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09l.01-.01zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
                    </svg>
                  )}
                  Continue with Apple
                </Button>

                {/* Sign in with Google */}
                <Button
                  onClick={handleGoogleLogin}
                  disabled={loading !== null}
                  className="w-full bg-white hover:bg-gray-100 text-gray-900 border border-gray-300 py-3"
                  size="lg"
                >
                  {loading === "google" ? (
                    <div className="animate-spin w-5 h-5 border-2 border-gray-900 border-t-transparent rounded-full mr-3" />
                  ) : (
                    <svg className="w-5 h-5 mr-3" viewBox="0 0 24 24">
                      <path
                        fill="#4285F4"
                        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                      />
                      <path
                        fill="#34A853"
                        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                      />
                      <path
                        fill="#FBBC05"
                        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                      />
                      <path
                        fill="#EA4335"
                        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                      />
                    </svg>
                  )}
                  Continue with Google
                </Button>
              </div>

              {/* Divider */}
              <div className="relative mb-6">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-card-border"></div>
                </div>
                <div className="relative flex justify-center text-xs uppercase">
                  <span className="bg-card-background px-2 text-foreground-muted">or continue with email</span>
                </div>
              </div>

              {/* Email Form */}
              <form onSubmit={authMode === "signin" ? handleEmailSignIn : handleEmailSignUp} className="space-y-4">
                {authMode === "signup" && (
                  <div>
                    <label htmlFor="fullName" className="block text-sm font-medium text-foreground-muted mb-1">
                      Full Name
                    </label>
                    <input
                      id="fullName"
                      type="text"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      placeholder="John Doe"
                      required={authMode === "signup"}
                      className="w-full px-4 py-3 rounded-lg bg-background border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green/50 focus:border-accent-green"
                    />
                  </div>
                )}

                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-foreground-muted mb-1">
                    Email
                  </label>
                  <input
                    id="email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    required
                    className="w-full px-4 py-3 rounded-lg bg-background border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green/50 focus:border-accent-green"
                  />
                </div>

                <div>
                  <label htmlFor="password" className="block text-sm font-medium text-foreground-muted mb-1">
                    Password
                  </label>
                  <div className="relative">
                    <input
                      id="password"
                      type={showPassword ? "text" : "password"}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      required
                      minLength={6}
                      className="w-full px-4 py-3 rounded-lg bg-background border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green/50 focus:border-accent-green pr-12"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-foreground-muted hover:text-foreground"
                    >
                      {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                    </button>
                  </div>
                </div>

                {authMode === "signin" && (
                  <div className="flex justify-end">
                    <button
                      type="button"
                      onClick={() => {
                        setAuthMode("forgot");
                        setError(null);
                        setSuccess(null);
                      }}
                      className="text-sm text-accent-green hover:underline"
                    >
                      Forgot password?
                    </button>
                  </div>
                )}

                <Button
                  type="submit"
                  disabled={loading !== null}
                  className="w-full py-3"
                  size="lg"
                >
                  {loading === "email" ? (
                    <div className="animate-spin w-5 h-5 border-2 border-white border-t-transparent rounded-full mr-3" />
                  ) : (
                    <Mail className="w-5 h-5 mr-2" />
                  )}
                  {authMode === "signin" ? "Sign In" : "Create Account"}
                </Button>
              </form>

              {/* Toggle Auth Mode */}
              <p className="text-center text-sm text-foreground-muted mt-6">
                {authMode === "signin" ? (
                  <>
                    Don&apos;t have an account?{" "}
                    <button
                      onClick={() => {
                        setAuthMode("signup");
                        setError(null);
                        setSuccess(null);
                      }}
                      className="text-accent-green hover:underline font-medium"
                    >
                      Sign up
                    </button>
                  </>
                ) : (
                  <>
                    Already have an account?{" "}
                    <button
                      onClick={() => {
                        setAuthMode("signin");
                        setError(null);
                        setSuccess(null);
                      }}
                      className="text-accent-green hover:underline font-medium"
                    >
                      Sign in
                    </button>
                  </>
                )}
              </p>
            </>
          )}

          {/* Forgot Password Form */}
          {authMode === "forgot" && (
            <form onSubmit={handleForgotPassword} className="space-y-4">
              <div>
                <label htmlFor="reset-email" className="block text-sm font-medium text-foreground-muted mb-1">
                  Email
                </label>
                <input
                  id="reset-email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  className="w-full px-4 py-3 rounded-lg bg-background border border-card-border text-foreground placeholder:text-foreground-muted/50 focus:outline-none focus:ring-2 focus:ring-accent-green/50 focus:border-accent-green"
                />
              </div>

              <Button
                type="submit"
                disabled={loading !== null}
                className="w-full py-3"
                size="lg"
              >
                {loading === "email" ? (
                  <div className="animate-spin w-5 h-5 border-2 border-white border-t-transparent rounded-full mr-3" />
                ) : (
                  <Mail className="w-5 h-5 mr-2" />
                )}
                Send Reset Link
              </Button>

              <button
                type="button"
                onClick={() => {
                  setAuthMode("signin");
                  setError(null);
                  setSuccess(null);
                }}
                className="w-full text-center text-sm text-foreground-muted hover:text-foreground"
              >
                ← Back to sign in
              </button>
            </form>
          )}

          {/* Footer */}
          <p className="text-center text-xs text-foreground-muted mt-6">
            By signing in, you agree to our Terms of Service and Privacy Policy
          </p>
        </div>

        {/* Bottom text */}
        <div className="text-center mt-6 space-y-2">
          <p className="text-sm text-foreground-muted">
            Tour-level strokes gained analytics for every golfer
          </p>
          <a 
            href="mailto:hello@roundcaddy.com" 
            className="text-xs text-foreground-muted hover:text-accent-green transition-colors"
          >
            hello@roundcaddy.com
          </a>
        </div>
      </div>
    </div>
  );
}
