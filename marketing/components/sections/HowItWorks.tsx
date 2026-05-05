const STEPS = [
  {
    n: "01",
    title: "Subscribe once.",
    body: "Pick a tier, confirm payment, done. No per-gym onboarding forms, no per-gym trials to juggle.",
  },
  {
    n: "02",
    title: "Walk in anywhere.",
    body: "Every partner gym has a static QR at reception. Open the app, point the phone, scan.",
  },
  {
    n: "03",
    title: "Train. Leave.",
    body: "We handle the accounting behind the scenes. Gyms get paid per visit. You get on with your set.",
  },
];

export function HowItWorks() {
  return (
    <section
      id="how"
      className="relative min-h-screen py-32 px-6 md:px-10 flex items-center"
    >
      <div className="max-w-6xl mx-auto w-full grid md:grid-cols-2 gap-16 items-center">
        <div>
          <p className="overline mb-6">How it works</p>
          <h2 className="headline-italic text-5xl md:text-7xl text-paper">
            Three moves.
            <br />
            <span className="serif-accent">That's it.</span>
          </h2>
          <p className="mt-8 text-lg text-paper-2 max-w-md leading-relaxed">
            No membership cards. No front-desk awkwardness. The only thing
            between you and the rack is a camera tap.
          </p>
        </div>

        <ol className="space-y-10">
          {STEPS.map((s) => (
            <li key={s.n} className="flex gap-6">
              <span className="font-mono text-lime text-sm pt-1">{s.n}</span>
              <div className="flex-1 border-l border-white/10 pl-6 pb-4">
                <h3 className="font-display font-black text-2xl tracking-tightest text-paper">
                  {s.title}
                </h3>
                <p className="text-paper-2 mt-2 leading-relaxed">{s.body}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
