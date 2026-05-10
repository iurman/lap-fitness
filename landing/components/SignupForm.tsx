"use client";

import { useState, FormEvent } from "react";

interface SignupFormProps {
  size?: "default" | "large";
  placeholder?: string;
}

export default function SignupForm({
  size = "default",
  placeholder = "Enter your email",
}: SignupFormProps) {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "loading" | "success" | "error">(
    "idle"
  );
  const [message, setMessage] = useState("");

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!email || state === "loading") return;

    setState("loading");
    setMessage("");

    try {
      const res = await fetch("/api/subscribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      const data = await res.json();

      if (!res.ok) throw new Error(data.error ?? "Something went wrong");

      setState("success");
      setMessage("You're on the list. We'll be in touch soon.");
      setEmail("");
    } catch (err) {
      setState("error");
      setMessage(
        err instanceof Error ? err.message : "Something went wrong. Try again."
      );
    }
  }

  const isLarge = size === "large";

  if (state === "success") {
    return (
      <div className="flex items-center gap-3 text-accent font-medium">
        <svg
          className="w-5 h-5 flex-shrink-0"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <span>{message}</span>
      </div>
    );
  }

  return (
    <div className="w-full">
      <form
        onSubmit={handleSubmit}
        className={`flex flex-col sm:flex-row gap-3 w-full ${isLarge ? "max-w-lg" : "max-w-md"}`}
      >
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={placeholder}
          required
          disabled={state === "loading"}
          className={`
            flex-1 bg-surface-2 border border-white/10 rounded-xl text-white
            placeholder:text-muted focus:outline-none focus:border-accent/60
            focus:ring-1 focus:ring-accent/30 transition-all disabled:opacity-60
            ${isLarge ? "px-5 py-4 text-base" : "px-4 py-3 text-sm"}
          `}
        />
        <button
          type="submit"
          disabled={state === "loading" || !email}
          className={`
            bg-accent hover:bg-accent-dim text-black font-semibold rounded-xl
            transition-all duration-200 whitespace-nowrap disabled:opacity-50
            disabled:cursor-not-allowed active:scale-95
            ${isLarge ? "px-7 py-4 text-base" : "px-5 py-3 text-sm"}
          `}
        >
          {state === "loading" ? (
            <span className="flex items-center gap-2">
              <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                <circle
                  className="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  strokeWidth="4"
                />
                <path
                  className="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8v8H4z"
                />
              </svg>
              Joining...
            </span>
          ) : (
            "Get Early Access"
          )}
        </button>
      </form>
      {state === "error" && (
        <p className="mt-2 text-sm text-red-400">{message}</p>
      )}
    </div>
  );
}
