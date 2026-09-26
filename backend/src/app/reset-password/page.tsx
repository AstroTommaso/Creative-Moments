"use client";

import { Suspense, useState, type FormEvent } from "react";
import { useSearchParams } from "next/navigation";

function ResetPasswordForm() {
  const token = useSearchParams().get("token") ?? "";
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<"idle" | "submitting" | "done" | "error">("idle");
  const [error, setError] = useState("");

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!token) {
      setError("This link is missing its token — request a new one from the app.");
      setStatus("error");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      setStatus("error");
      return;
    }
    setStatus("submitting");
    const res = await fetch("/api/auth/reset-password", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token, password }),
    });
    if (res.ok) {
      setStatus("done");
    } else {
      setError("This link is invalid or has expired. Request a new one from the app.");
      setStatus("error");
    }
  }

  if (status === "done") {
    return (
      <>
        <h1 style={styles.h1}>Password updated</h1>
        <p>You can go back to Creative Moments and log in with your new password.</p>
      </>
    );
  }

  return (
    <>
      <h1 style={styles.h1}>Choose a new password</h1>
      <form onSubmit={onSubmit} style={styles.form}>
        <input
          type="password"
          placeholder="New password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          style={styles.input}
          minLength={8}
          required
        />
        {status === "error" && <p style={styles.error}>{error}</p>}
        <button type="submit" disabled={status === "submitting"} style={styles.button}>
          {status === "submitting" ? "Saving…" : "Save password"}
        </button>
      </form>
    </>
  );
}

export default function ResetPasswordPage() {
  return (
    <main style={styles.main}>
      <Suspense fallback={<p>Loading…</p>}>
        <ResetPasswordForm />
      </Suspense>
    </main>
  );
}

const styles: Record<string, React.CSSProperties> = {
  main: { maxWidth: 420, margin: "10vh auto", padding: "0 24px", fontFamily: "system-ui, sans-serif" },
  h1: { fontSize: 22, marginBottom: 16 },
  form: { display: "flex", flexDirection: "column", gap: 12 },
  input: { padding: 12, fontSize: 16, borderRadius: 8, border: "1px solid #ccc" },
  button: { padding: 12, fontSize: 16, borderRadius: 8, border: "none", background: "#111", color: "#fff", cursor: "pointer" },
  error: { color: "#c0392b", fontSize: 14 },
};
