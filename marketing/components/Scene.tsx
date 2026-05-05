"use client";

import { Canvas } from "@react-three/fiber";
import { AdaptiveDpr, AdaptiveEvents, Environment } from "@react-three/drei";
import { Suspense, useEffect, useMemo, useState } from "react";
import * as THREE from "three";
import { Particles } from "./scene/Particles";
import { TierOrbs } from "./scene/TierOrbs";
import { Equipment } from "./scene/Equipment";
import { FloatingPhone } from "./scene/FloatingPhone";
import { useScrollProgress } from "../hooks/useScrollProgress";
import { useReducedMotion } from "../hooks/useReducedMotion";

function clamp(v: number, a: number, b: number) {
  return Math.max(a, Math.min(b, v));
}

function lerp(a: number, b: number, t: number) {
  return a + (b - a) * clamp(t, 0, 1);
}

function SceneContents({ progress }: { progress: number }) {
  // 6 sections, progress 0..1 — map to scene beats.
  // beat 0 (hero, 0.0..0.17): orbs centered
  // beat 1 (tiers, 0.17..0.33): orbs expand, emphasize tiers
  // beat 2 (how, 0.33..0.50): phone takes stage
  // beat 3 (network, 0.50..0.67): equipment drifts forward
  // beat 4 (pricing, 0.67..0.83): phone + orbs re-compose
  // beat 5 (cta, 0.83..1.0): pull back, lime wash

  const cam = useMemo(() => new THREE.Vector3(), []);
  const camY = lerp(0.0, -1.2, progress * 1.1);
  const camZ = 6 + Math.sin(progress * Math.PI) * 1.2 - progress * 1.4;
  cam.set(0, camY, camZ);

  return (
    <>
      <color attach="background" args={["#0A0B0A"]} />
      <fog attach="fog" args={["#0A0B0A", 8, 22]} />

      <ambientLight intensity={0.35} />
      <directionalLight
        position={[5, 6, 4]}
        intensity={1.1}
        color="#F4F4F0"
      />
      <pointLight
        position={[-3, 2, 2]}
        intensity={1.4}
        color="#BBFB46"
        distance={10}
      />
      <pointLight
        position={[0, -2, 3]}
        intensity={0.9}
        color="#64D2FF"
        distance={8}
      />

      <group position={cam.toArray()}>
        {/* camera-follow container is implicit — actual positioning below */}
      </group>

      <Particles progress={progress} />

      <group position={[0, lerp(0.3, -0.6, progress), 0]}>
        <TierOrbs progress={progress} />
      </group>

      <group
        position={[
          lerp(3.5, 0, clamp((progress - 0.28) * 3.2, 0, 1)),
          lerp(-0.4, 0.2, clamp((progress - 0.28) * 3.2, 0, 1)),
          lerp(-2, 1, clamp((progress - 0.28) * 3.2, 0, 1)),
        ]}
        scale={lerp(0.7, 1.15, clamp((progress - 0.28) * 3.2, 0, 1))}
      >
        <FloatingPhone progress={progress} />
      </group>

      <Equipment progress={progress} />

      <Suspense fallback={null}>
        <Environment preset="night" />
      </Suspense>
    </>
  );
}

export function Scene() {
  const progress = useScrollProgress();
  const reduced = useReducedMotion();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <div
        aria-hidden
        className="fixed inset-0 -z-10 bg-ink"
        style={{
          background:
            "radial-gradient(circle at 50% 40%, rgba(187,251,70,0.12), transparent 55%), #0A0B0A",
        }}
      />
    );
  }

  if (reduced) {
    return (
      <div
        aria-hidden
        className="fixed inset-0 -z-10 bg-ink"
        style={{
          background:
            "radial-gradient(circle at 50% 40%, rgba(187,251,70,0.15), transparent 55%), radial-gradient(circle at 80% 70%, rgba(100,210,255,0.08), transparent 45%), #0A0B0A",
        }}
      />
    );
  }

  return (
    <div
      aria-hidden
      className="fixed inset-0 -z-10"
      style={{ pointerEvents: "none" }}
    >
      <Canvas
        dpr={[1, 1.75]}
        gl={{
          antialias: true,
          alpha: false,
          powerPreference: "high-performance",
        }}
        camera={{ position: [0, 0, 6], fov: 45 }}
        shadows={false}
      >
        <AdaptiveDpr pixelated={false} />
        <AdaptiveEvents />
        <SceneContents progress={progress} />
      </Canvas>
    </div>
  );
}
