const STATS = [
  { k: "200+", v: "Partner gyms" },
  { k: "12", v: "Governorates" },
  { k: "4", v: "Disciplines" },
  { k: "0", v: "Per-gym contracts" },
];

const CITIES = [
  "Amman",
  "Irbid",
  "Zarqa",
  "Aqaba",
  "Madaba",
  "Salt",
  "Jerash",
  "Karak",
];

export function Network() {
  return (
    <section
      id="network"
      className="relative min-h-screen py-32 px-6 md:px-10 flex items-center"
    >
      <div className="max-w-6xl mx-auto w-full">
        <p className="overline mb-6">The network</p>
        <h2 className="headline-italic text-5xl md:text-7xl text-paper max-w-3xl">
          From the Gulf of Aqaba
          <br />
          to <span className="serif-accent">the north.</span>
        </h2>

        <div className="mt-16 grid md:grid-cols-4 gap-4">
          {STATS.map((s) => (
            <div
              key={s.v}
              className="glass rounded-2xl p-6 flex flex-col gap-1"
            >
              <div className="font-display font-black text-5xl tracking-tightest text-lime">
                {s.k}
              </div>
              <div className="text-paper-3 text-sm font-mono uppercase tracking-[0.18em]">
                {s.v}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-16 flex flex-wrap gap-2">
          {CITIES.map((c) => (
            <span
              key={c}
              className="px-4 py-2 rounded-full border border-white/10 text-paper-2 text-sm bg-white/[0.02]"
            >
              {c}
            </span>
          ))}
          <span className="px-4 py-2 rounded-full border border-lime/40 text-lime text-sm">
            + more monthly
          </span>
        </div>

        <div className="mt-16 grid md:grid-cols-4 gap-3 text-paper-2 text-sm">
          {["Gyms", "CrossFit", "Martial arts", "Yoga"].map((cat) => (
            <div
              key={cat}
              className="border border-white/10 rounded-xl px-4 py-5 flex items-center justify-between"
            >
              <span>{cat}</span>
              <span className="font-mono text-paper-3">→</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
