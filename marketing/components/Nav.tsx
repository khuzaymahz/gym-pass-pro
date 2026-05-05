"use client";

import { useEffect, useState } from "react";

const LINKS = [
  { href: "#tiers", label: "Tiers" },
  { href: "#how", label: "How it works" },
  { href: "#network", label: "Network" },
  { href: "#pricing", label: "Pricing" },
];

export function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <nav
      className={`fixed top-0 inset-x-0 z-50 transition-[background,backdrop-filter,border-color] duration-300 ${
        scrolled
          ? "bg-ink/70 backdrop-blur-md border-b border-white/5"
          : "bg-transparent border-b border-transparent"
      }`}
    >
      <div className="max-w-6xl mx-auto px-6 md:px-10 h-16 flex items-center justify-between">
        <a href="#top" className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg bg-lime flex items-center justify-center text-ink font-display font-black text-lg tracking-tightest transition-transform group-hover:rotate-6">
            G
          </div>
          <span className="font-display font-black tracking-tightest text-paper">
            Gym&nbsp;Pass
          </span>
        </a>

        <div className="hidden md:flex items-center gap-7 text-sm text-paper-2">
          {LINKS.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="hover:text-paper transition-colors"
            >
              {l.label}
            </a>
          ))}
        </div>

        <a href="#cta" className="btn-lime text-sm">
          Get the app
          <span aria-hidden>→</span>
        </a>
      </div>
    </nav>
  );
}
