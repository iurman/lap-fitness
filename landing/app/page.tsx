import SignupForm from "@/components/SignupForm";

const features = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    ),
    title: "Workout Tracking",
    description:
      "Log every rep, set, and session with a clean interface built for speed. From strength training to cardio — track it all in one place.",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
      </svg>
    ),
    title: "Nutrition Logging",
    description:
      "Search millions of foods instantly with barcode scanning. Track macros, calories, and meal history without the friction.",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 3c-4.97 0-9 3.694-9 8.25 0 2.583.962 4.935 2.55 6.704L5.25 21l3.5-1.25A9.044 9.044 0 0012 20.25c4.97 0 9-3.694 9-8.25S16.97 3 12 3z" />
      </svg>
    ),
    title: "Hydration Goals",
    description:
      "Set daily water targets and log intake throughout the day. Simple, visual reminders keep you on track without being annoying.",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
      </svg>
    ),
    title: "Social Feed",
    description:
      "Share workouts, celebrate milestones, and stay accountable with your community. Fitness is more fun when you do it together.",
  },
];

const steps = [
  { number: "01", title: "Create your profile", body: "Set your goals, activity level, and preferences in under a minute." },
  { number: "02", title: "Log your day", body: "Track workouts, meals, and water from one unified dashboard." },
  { number: "03", title: "See your progress", body: "Watch your streaks grow and your stats improve over time." },
];

export default function Home() {
  return (
    <div className="min-h-screen bg-background">
      {/* Nav */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-background/80 backdrop-blur-md border-b border-white/5">
        <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 bg-accent rounded-lg flex items-center justify-center">
              <svg className="w-4 h-4 text-black" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
              </svg>
            </div>
            <span className="font-bold text-white tracking-tight">LAP Fitness</span>
          </div>
          <a
            href="#waitlist"
            className="text-sm font-medium text-accent hover:text-white transition-colors"
          >
            Get Early Access
          </a>
        </div>
      </nav>

      <main>
        {/* Hero */}
        <section className="relative pt-32 pb-24 px-6 overflow-hidden">
          {/* Glow background */}
          <div
            aria-hidden="true"
            className="absolute inset-0 pointer-events-none"
            style={{
              background:
                "radial-gradient(ellipse 70% 40% at 50% 0%, rgba(74,222,128,0.10) 0%, transparent 70%)",
            }}
          />
          {/* Subtle grid */}
          <div
            aria-hidden="true"
            className="absolute inset-0 pointer-events-none opacity-[0.03]"
            style={{
              backgroundImage:
                "linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)",
              backgroundSize: "60px 60px",
            }}
          />

          <div className="relative max-w-4xl mx-auto text-center">
            <div className="inline-flex items-center gap-2 bg-accent/10 border border-accent/20 rounded-full px-4 py-1.5 mb-8">
              <span className="w-1.5 h-1.5 rounded-full bg-accent animate-pulse" />
              <span className="text-sm text-accent font-medium">Now accepting early access signups</span>
            </div>

            <h1 className="text-5xl sm:text-6xl lg:text-7xl font-extrabold text-white leading-[1.08] tracking-tight text-balance mb-6">
              One app for your{" "}
              <span className="text-accent">entire fitness life</span>
            </h1>

            <p className="text-lg sm:text-xl text-muted leading-relaxed max-w-2xl mx-auto mb-10 text-balance">
              LAP Fitness brings workout tracking, nutrition logging, hydration goals, and a social community into a single, beautifully simple app.
            </p>

            <div className="flex justify-center mb-4">
              <SignupForm size="large" placeholder="Enter your email address" />
            </div>
            <p className="text-sm text-muted">
              Free early access. No credit card. Be the first to know when we launch.
            </p>
          </div>
        </section>

        {/* Stats bar */}
        <section className="border-y border-white/5 bg-surface/40">
          <div className="max-w-4xl mx-auto px-6 py-10 grid grid-cols-3 gap-6 text-center">
            {[
              { value: "All-in-one", label: "Fitness dashboard" },
              { value: "Real-time", label: "Nutrition database" },
              { value: "Social", label: "Community built in" },
            ].map((stat) => (
              <div key={stat.label}>
                <div className="text-2xl font-bold text-white mb-1">{stat.value}</div>
                <div className="text-sm text-muted">{stat.label}</div>
              </div>
            ))}
          </div>
        </section>

        {/* Features */}
        <section id="features" className="py-24 px-6">
          <div className="max-w-6xl mx-auto">
            <div className="text-center mb-16">
              <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
                Everything you need to crush your goals
              </h2>
              <p className="text-muted text-lg max-w-xl mx-auto text-balance">
                Purpose-built tools that work together — no juggling five different apps.
              </p>
            </div>

            <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
              {features.map((feature) => (
                <div
                  key={feature.title}
                  className="group bg-surface border border-white/5 rounded-2xl p-6 hover:border-accent/30 hover:bg-surface-2 transition-all duration-300"
                >
                  <div className="w-11 h-11 bg-accent/10 border border-accent/20 rounded-xl flex items-center justify-center text-accent mb-5 group-hover:bg-accent/15 transition-colors">
                    {feature.icon}
                  </div>
                  <h3 className="font-semibold text-white mb-2">{feature.title}</h3>
                  <p className="text-sm text-muted leading-relaxed">{feature.description}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* How it works */}
        <section className="py-24 px-6 bg-surface/30">
          <div className="max-w-4xl mx-auto">
            <div className="text-center mb-16">
              <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
                Simple by design
              </h2>
              <p className="text-muted text-lg max-w-xl mx-auto">
                Getting started takes less than two minutes. Staying consistent has never been easier.
              </p>
            </div>

            <div className="grid sm:grid-cols-3 gap-8">
              {steps.map((step, i) => (
                <div key={step.number} className="relative text-center sm:text-left">
                  {/* connector line */}
                  {i < steps.length - 1 && (
                    <div
                      aria-hidden="true"
                      className="hidden sm:block absolute top-5 left-[calc(50%+2rem)] right-0 h-px bg-gradient-to-r from-accent/30 to-transparent"
                    />
                  )}
                  <div className="text-5xl font-black text-accent/15 mb-4 leading-none">
                    {step.number}
                  </div>
                  <h3 className="font-semibold text-white mb-2">{step.title}</h3>
                  <p className="text-sm text-muted leading-relaxed">{step.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* CTA / Waitlist */}
        <section id="waitlist" className="py-24 px-6 relative overflow-hidden">
          <div
            aria-hidden="true"
            className="absolute inset-0 pointer-events-none"
            style={{
              background:
                "radial-gradient(ellipse 60% 50% at 50% 100%, rgba(74,222,128,0.08) 0%, transparent 70%)",
            }}
          />
          <div className="relative max-w-2xl mx-auto text-center">
            <div className="inline-flex items-center gap-2 bg-accent/10 border border-accent/20 rounded-full px-4 py-1.5 mb-8">
              <span className="text-sm text-accent font-medium">Launching soon</span>
            </div>

            <h2 className="text-4xl sm:text-5xl font-extrabold text-white mb-5 tracking-tight text-balance">
              Be first in the door
            </h2>
            <p className="text-muted text-lg mb-10 max-w-md mx-auto text-balance">
              Drop your email below and we&apos;ll reach out the moment LAP Fitness is ready.
              Early access. No spam. Ever.
            </p>

            <div className="flex justify-center">
              <SignupForm size="large" />
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-white/5 py-10 px-6">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 bg-accent rounded-md flex items-center justify-center">
              <svg className="w-3.5 h-3.5 text-black" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
              </svg>
            </div>
            <span className="font-semibold text-white text-sm">LAP Fitness</span>
          </div>
          <p className="text-muted text-sm">
            © {new Date().getFullYear()} LAP Fitness. All rights reserved.
          </p>
          <div className="flex items-center gap-6 text-sm text-muted">
            <span>Built by Isaac Urman &amp; Darrian Yang</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
