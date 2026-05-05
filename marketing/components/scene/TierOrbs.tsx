"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";

const TIERS: { color: string; emissive: string; angle: number }[] = [
  { color: "#C0C0C0", emissive: "#8E8F86", angle: 0 },
  { color: "#FFD60A", emissive: "#B8910A", angle: Math.PI / 2 },
  { color: "#30D158", emissive: "#1B8A3A", angle: Math.PI },
  { color: "#64D2FF", emissive: "#2E8CBE", angle: Math.PI * 1.5 },
];

export function TierOrbs({ progress }: { progress: number }) {
  const group = useRef<THREE.Group>(null);

  useFrame((state) => {
    if (!group.current) return;
    const t = state.clock.elapsedTime;
    group.current.rotation.y = t * 0.12 + progress * Math.PI;
    group.current.rotation.x = Math.sin(t * 0.2) * 0.08;
    const spread = 1.6 + progress * 0.8;
    group.current.children.forEach((child, i) => {
      const a = TIERS[i].angle + t * 0.25;
      child.position.x = Math.cos(a) * spread;
      child.position.z = Math.sin(a) * spread;
      child.position.y = Math.sin(t * 0.6 + i) * 0.18;
    });
  });

  return (
    <group ref={group}>
      {TIERS.map((tier, i) => (
        <mesh key={i} castShadow>
          <sphereGeometry args={[0.48, 48, 48]} />
          <meshStandardMaterial
            color={tier.color}
            emissive={tier.emissive}
            emissiveIntensity={0.6}
            metalness={0.3}
            roughness={0.35}
          />
        </mesh>
      ))}
    </group>
  );
}
