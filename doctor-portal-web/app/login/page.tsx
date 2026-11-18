"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { sendPasswordResetEmail } from "firebase/auth";
import { Activity } from "lucide-react";
import { toast } from "sonner";
import { useAuth } from "@/components/providers/auth-provider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Disclaimer } from "@/components/feedback/disclaimer";
import { Skeleton } from "@/components/ui/skeleton";
import { authErrorMessage, getFirebaseAuth } from "@/lib/firebase";

export default function LoginPage() {
  const { user, doctor, doctorError, loading, signIn, signOut, reloadDoctor } =
    useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && doctor) {
      router.replace("/enquiries");
    }
  }, [doctor, loading, router]);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setPending(true);
    try {
      await signIn(email, password);
    } catch (err) {
      setError(authErrorMessage(err));
      setPending(false);
    }
  }

  async function onReset() {
    setError(null);
    if (!email.trim()) {
      setError("Enter your email first, then request a reset link.");
      return;
    }
    try {
      await sendPasswordResetEmail(getFirebaseAuth(), email.trim());
      toast.success("Password reset email sent.");
    } catch (err) {
      setError(authErrorMessage(err));
    }
  }

  if (loading || doctor) {
    return (
      <div className="flex min-h-full items-center justify-center bg-page-bg p-8">
        <Skeleton className="h-80 w-full max-w-md rounded-card" />
      </div>
    );
  }

  if (user && !doctor) {
    return (
      <div className="flex min-h-full items-center justify-center bg-page-bg px-4 py-12">
        <div className="w-full max-w-md rounded-card bg-panel p-8 shadow-frame">
          <h1 className="text-3xl font-extrabold text-ink">
            {doctorError ? "Could not load doctor profile" : "Not a doctor account"}
          </h1>
          <p className="mt-3 text-sm font-medium leading-relaxed text-ink-muted">
            {doctorError ? (
              doctorError
            ) : (
              <>
                {user.email ?? "This user"} can sign in, but there is no doctor
                profile yet. In Firestore, create a document at{" "}
                <span className="font-bold text-ink">doctors/{user.uid}</span>{" "}
                with a name, email, and specialty, then check again.
              </>
            )}
          </p>
          {!doctorError ? (
            <pre className="mt-4 overflow-x-auto rounded-2xl bg-chip p-4 text-xs leading-relaxed text-ink">
{`{
  "name": "Dr. Anika Shah",
  "email": "${user.email ?? "doctor@clinic.com"}",
  "specialty": "General medicine",
  "active": true
}`}
            </pre>
          ) : null}
          <div className="mt-6 flex gap-2">
            <Button type="button" className="flex-1" onClick={() => void reloadDoctor()}>
              Check again
            </Button>
            <Button type="button" variant="outline" onClick={() => void signOut()}>
              Sign out
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-full items-center justify-center bg-page-bg px-4 py-12">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-md rounded-card bg-panel p-8 shadow-frame"
      >
        <div className="flex items-center gap-2 font-extrabold text-ink">
          <span className="flex size-10 items-center justify-center rounded-2xl bg-cream">
            <Activity className="size-5 text-accent-ink" />
          </span>
          Doctor portal
        </div>
        <h1 className="mt-6 text-3xl font-extrabold text-ink">Sign in</h1>
        <p className="mt-2 text-sm font-medium text-ink-muted">
          For clinicians reviewing patient enquiries.
        </p>

        <div className="mt-6 space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="h-12 rounded-full px-4"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="h-12 rounded-full px-4"
            />
          </div>
        </div>

        {error ? (
          <p className="mt-4 text-sm font-semibold text-bad" role="alert">
            {error}
          </p>
        ) : null}

        <Button type="submit" className="mt-6 w-full" size="lg" disabled={pending}>
          {pending ? "Signing in…" : "Sign in"}
        </Button>
        <button
          type="button"
          onClick={() => void onReset()}
          className="mt-4 w-full text-center text-sm font-bold text-accent-ink"
        >
          Email me a reset link
        </button>
        <div className="mt-6">
          <Disclaimer />
        </div>
      </form>
    </div>
  );
}
