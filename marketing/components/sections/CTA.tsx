export function CTA() {
  return (
    <section
      id="cta"
      className="relative min-h-[80vh] py-32 px-6 md:px-10 flex items-center"
    >
      <div className="max-w-5xl mx-auto w-full text-center">
        <p className="overline mb-8">Ready when you are</p>
        <h2 className="headline-italic text-6xl md:text-[9rem] text-paper">
          Get the
          <br />
          <span className="text-lime not-italic font-display">pass.</span>
        </h2>
        <p className="mt-10 text-paper-2 text-lg md:text-xl max-w-xl mx-auto leading-relaxed">
          Download the app, pick a tier, and scan at the nearest gym{" "}
          <span className="serif-accent">tonight.</span>
        </p>
        <div className="mt-12 flex flex-wrap gap-3 justify-center">
          <a href="#" className="btn-lime">
            Download for iOS
            <span aria-hidden>→</span>
          </a>
          <a href="#" className="btn-ghost">
            Download for Android
          </a>
        </div>

        <footer className="mt-32 pt-10 border-t border-white/10 flex flex-col md:flex-row items-center justify-between gap-6 text-paper-3 text-sm">
          <div className="flex items-center gap-2.5">
            <div className="w-6 h-6 rounded-md bg-lime text-ink font-display font-black flex items-center justify-center text-xs">
              G
            </div>
            <span className="font-mono uppercase tracking-[0.2em]">
              Gym Pass · Jordan
            </span>
          </div>
          <div className="flex gap-6">
            <a href="#" className="hover:text-paper transition-colors">
              Gym partners
            </a>
            <a href="#" className="hover:text-paper transition-colors">
              Privacy
            </a>
            <a href="#" className="hover:text-paper transition-colors">
              Terms
            </a>
          </div>
        </footer>
      </div>
    </section>
  );
}
