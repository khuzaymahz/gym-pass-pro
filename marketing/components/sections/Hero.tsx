export function Hero() {
  return (
    <section
      id="top"
      className="relative min-h-screen flex items-center px-6 md:px-10 pt-24"
    >
      <div className="max-w-6xl mx-auto w-full">
        <p className="overline mb-6">One pass · Every gym · Jordan</p>
        <h1 className="headline-italic text-[14vw] md:text-[9.5rem] text-paper max-w-5xl">
          Lift anywhere.
          <br />
          <span className="text-lime not-italic font-display">Pay once.</span>
        </h1>
        <p className="mt-10 max-w-xl text-lg md:text-xl text-paper-2 leading-relaxed">
          One subscription opens the door to hundreds of gyms across the
          kingdom. <span className="serif-accent">No per-gym contracts.</span>{" "}
          No paperwork. Just scan and train.
        </p>
        <div className="mt-10 flex flex-wrap gap-3">
          <a href="#cta" className="btn-lime">
            Download for iOS
            <span aria-hidden>→</span>
          </a>
          <a href="#how" className="btn-ghost">
            See how it works
          </a>
        </div>

        <div className="absolute bottom-10 left-1/2 -translate-x-1/2 hidden md:flex flex-col items-center gap-2 text-paper-3 text-xs font-mono uppercase tracking-[0.3em]">
          <span>Scroll</span>
          <span aria-hidden className="w-px h-10 bg-paper-3/40" />
        </div>
      </div>
    </section>
  );
}
