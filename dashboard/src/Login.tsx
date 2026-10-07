import { useState } from "react";
import { supabase } from "./lib/api";

/**
 * Email magic link. `shouldCreateUser: false`: only accounts created by the
 * team in Supabase (Authentication → Users → Invite) can receive a link.
 */
export function Login() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "sent">("idle");
  const [error, setError] = useState<string | null>(null);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!supabase) return;
    setState("sending");
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { shouldCreateUser: false, emailRedirectTo: window.location.origin + window.location.pathname },
    });
    if (error) {
      setError("Impossible d’envoyer le lien. Vérifie que ce compte a été invité dans Supabase.");
      setState("idle");
    } else {
      setState("sent");
    }
  }

  return (
    <div className="login">
      <h1 className="brand">quieto</h1>
      <p className="muted">Analytics</p>
      {state === "sent" ? (
        <p role="status">
          Lien de connexion envoyé à <strong>{email}</strong>. Ouvre-le sur cet appareil.
        </p>
      ) : (
        <form onSubmit={submit}>
          <label htmlFor="email">Email</label>
          <input id="email" type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <button className="primary" disabled={state === "sending"}>
            {state === "sending" ? "Envoi…" : "Recevoir un lien de connexion"}
          </button>
          {error && (
            <p className="error" role="alert">
              {error}
            </p>
          )}
        </form>
      )}
    </div>
  );
}
