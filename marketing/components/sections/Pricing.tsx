const FAQ = [
  {
    q: "Can I change tier mid-month?",
    a: "Anytime. We pro-rate the difference and your next billing cycle picks up the new tier.",
  },
  {
    q: "What if a gym turns me away?",
    a: "Every partner gym signs an access SLA. If the QR scans clean and you're turned away, open a ticket in the app — we credit the visit back.",
  },
  {
    q: "How does payment work?",
    a: "Card, CliQ or Apple Pay. Gyms are paid per verified check-in, monthly. No revenue-share surprises on either side.",
  },
];

export function Pricing() {
  return (
    <section
      id="pricing"
      className="relative min-h-screen py-32 px-6 md:px-10 flex items-center"
    >
      <div className="max-w-6xl mx-auto w-full grid md:grid-cols-2 gap-16">
        <div>
          <p className="overline mb-6">The shape of the deal</p>
          <h2 className="headline-italic text-5xl md:text-7xl text-paper">
            Simple where it <span className="serif-accent">counts.</span>
          </h2>
          <p className="mt-8 text-paper-2 max-w-md leading-relaxed text-lg">
            Cancel online. Upgrade in-app. No three-month lock-ins, no signing
            clipboards, no "let me check with the manager."
          </p>

          <div className="mt-10 flex gap-3 flex-wrap">
            <a href="#cta" className="btn-lime">
              Start with Silver
              <span aria-hidden>→</span>
            </a>
            <a href="#tiers" className="btn-ghost">
              Compare tiers
            </a>
          </div>
        </div>

        <div className="space-y-4">
          {FAQ.map((item) => (
            <details
              key={item.q}
              className="glass rounded-2xl p-6 group cursor-pointer"
            >
              <summary className="flex items-center justify-between gap-6 list-none">
                <span className="font-display font-black text-lg tracking-tight text-paper">
                  {item.q}
                </span>
                <span
                  aria-hidden
                  className="text-lime text-xl transition-transform group-open:rotate-45"
                >
                  +
                </span>
              </summary>
              <p className="text-paper-2 mt-4 leading-relaxed">{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
