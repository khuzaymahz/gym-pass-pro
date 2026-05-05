const TIERS = [
  {
    name: "Silver",
    price: "25",
    visits: "8 visits / mo",
    blurb: "Dip a toe in. Best for occasional lifters.",
    color: "#C0C0C0",
    glow: "rgba(192,192,192,0.25)",
  },
  {
    name: "Gold",
    price: "45",
    visits: "16 visits / mo",
    blurb: "The sweet spot. Four sessions a week.",
    color: "#FFD60A",
    glow: "rgba(255,214,10,0.3)",
  },
  {
    name: "Platinum",
    price: "65",
    visits: "Unlimited",
    blurb: "Live at the gym. Any time, any location.",
    color: "#B8D4FF",
    glow: "rgba(184,212,255,0.35)",
    featured: true,
  },
  {
    name: "Diamond",
    price: "95",
    visits: "Unlimited + premium",
    blurb: "Everything in Platinum plus boutique studios.",
    color: "#64D2FF",
    glow: "rgba(100,210,255,0.3)",
  },
];

export function Tiers() {
  return (
    <section
      id="tiers"
      className="relative min-h-screen py-32 px-6 md:px-10 flex items-center"
    >
      <div className="max-w-6xl mx-auto w-full">
        <p className="overline mb-6">Four tiers</p>
        <h2 className="headline-italic text-5xl md:text-7xl text-paper max-w-3xl">
          Pick the shape
          <br />
          of your <span className="serif-accent">routine.</span>
        </h2>

        <div className="mt-16 grid gap-4 md:grid-cols-4">
          {TIERS.map((t) => (
            <div
              key={t.name}
              className={`glass rounded-3xl p-6 flex flex-col gap-4 relative transition-transform hover:-translate-y-1 ${
                t.featured ? "ring-1 ring-lime/40" : ""
              }`}
              style={{
                boxShadow: `0 20px 60px -25px ${t.glow}`,
              }}
            >
              {t.featured && (
                <span className="absolute -top-3 left-6 text-[10px] font-mono uppercase tracking-[0.22em] bg-lime text-ink px-2.5 py-1 rounded-full">
                  Most picked
                </span>
              )}
              <div
                className="w-10 h-10 rounded-full"
                style={{
                  background: `radial-gradient(circle at 30% 30%, ${t.color}, transparent 70%)`,
                  boxShadow: `0 0 30px ${t.glow}`,
                }}
                aria-hidden
              />
              <div>
                <div className="font-display font-black text-2xl tracking-tightest text-paper">
                  {t.name}
                </div>
                <div className="text-paper-3 text-sm mt-0.5">{t.visits}</div>
              </div>
              <div className="mt-auto">
                <div className="flex items-baseline gap-1">
                  <span className="font-display font-black text-4xl tracking-tightest text-paper">
                    {t.price}
                  </span>
                  <span className="text-paper-3 text-sm">JOD / mo</span>
                </div>
                <p className="text-paper-2 text-sm mt-3 leading-relaxed">
                  {t.blurb}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
