import { Nav } from "../components/Nav";
import { SceneClient } from "../components/SceneClient";
import { Hero } from "../components/sections/Hero";
import { Tiers } from "../components/sections/Tiers";
import { HowItWorks } from "../components/sections/HowItWorks";
import { Network } from "../components/sections/Network";
import { Pricing } from "../components/sections/Pricing";
import { CTA } from "../components/sections/CTA";

export default function Page() {
  return (
    <>
      <SceneClient />
      <Nav />
      <main className="relative">
        <Hero />
        <Tiers />
        <HowItWorks />
        <Network />
        <Pricing />
        <CTA />
      </main>
    </>
  );
}
