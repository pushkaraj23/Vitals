"use client";

import { createContext, useContext, useEffect, useMemo, useRef, useState } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  type User,
} from "firebase/auth";
import { fetchDoctorProfile, type DoctorProfile } from "@/lib/doctor";
import { getFirebaseAuth } from "@/lib/firebase";

interface AuthContextValue {
  user: User | null;
  doctor: DoctorProfile | null;
  doctorError: string | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  reloadDoctor: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [doctor, setDoctor] = useState<DoctorProfile | null>(null);
  const [doctorError, setDoctorError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const userRef = useRef<User | null>(null);

  useEffect(() => {
    const auth = getFirebaseAuth();
    return onAuthStateChanged(auth, async (next) => {
      const sameUser = next?.uid != null && next.uid === userRef.current?.uid;
      userRef.current = next;
      if (!sameUser) setLoading(true);
      setUser(next);
      if (!next) {
        setDoctor(null);
        setDoctorError(null);
        setLoading(false);
        return;
      }
      try {
        setDoctor(await fetchDoctorProfile(next));
        setDoctorError(null);
      } catch (error) {
        setDoctor(null);
        setDoctorError(
          error instanceof Error ? error.message : "Could not load doctor profile."
        );
      } finally {
        setLoading(false);
      }
    });
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      doctor,
      doctorError,
      loading,
      async signIn(email: string, password: string) {
        await signInWithEmailAndPassword(
          getFirebaseAuth(),
          email.trim(),
          password
        );
      },
      async signOut() {
        await firebaseSignOut(getFirebaseAuth());
        setDoctor(null);
        setDoctorError(null);
      },
      async reloadDoctor() {
        const current = getFirebaseAuth().currentUser;
        if (!current) return;
        setLoading(true);
        try {
          setDoctor(await fetchDoctorProfile(current));
          setDoctorError(null);
        } catch (error) {
          setDoctor(null);
          setDoctorError(
            error instanceof Error
              ? error.message
              : "Could not load doctor profile."
          );
        } finally {
          setLoading(false);
        }
      },
    }),
    [user, doctor, doctorError, loading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
}
