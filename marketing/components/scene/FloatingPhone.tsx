"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";

export function FloatingPhone({ progress }: { progress: number }) {
  const group = useRef<THREE.Group>(null);
  const screen = useRef<THREE.MeshStandardMaterial>(null);

  useFrame((state) => {
    if (!group.current) return;
    const t = state.clock.elapsedTime;
    const tilt = Math.sin(t * 0.5) * 0.08;
    const swing = Math.cos(t * 0.4) * 0.05;
    group.current.rotation.x = -0.18 + tilt;
    group.current.rotation.y = swing + progress * Math.PI * 0.25;
    group.current.position.y = Math.sin(t * 0.6) * 0.12;
    if (screen.current) {
      const pulse = 0.55 + (Math.sin(t * 1.6) + 1) * 0.18;
      screen.current.emissiveIntensity = pulse;
    }
  });

  return (
    <group ref={group}>
      {/* body */}
      <mesh castShadow>
        <boxGeometry args={[1.35, 2.7, 0.12]} />
        <meshStandardMaterial
          color="#111312"
          metalness={0.75}
          roughness={0.25}
        />
      </mesh>
      {/* bezel frame */}
      <mesh position={[0, 0, 0.065]}>
        <boxGeometry args={[1.22, 2.55, 0.012]} />
        <meshStandardMaterial color="#0A0B0A" />
      </mesh>
      {/* screen */}
      <mesh position={[0, 0, 0.075]}>
        <planeGeometry args={[1.18, 2.5]} />
        <meshStandardMaterial
          ref={screen}
          color="#0A0B0A"
          emissive="#BBFB46"
          emissiveIntensity={0.55}
          roughness={0.2}
          metalness={0.0}
        />
      </mesh>
      {/* qr-like grid accent */}
      <mesh position={[0, -0.35, 0.082]}>
        <planeGeometry args={[0.55, 0.55]} />
        <meshStandardMaterial
          color="#0A0B0A"
          emissive="#D5FF7E"
          emissiveIntensity={0.9}
          roughness={0.3}
        />
      </mesh>
      {/* home indicator */}
      <mesh position={[0, -1.15, 0.08]}>
        <boxGeometry args={[0.45, 0.03, 0.002]} />
        <meshStandardMaterial color="#5A5B54" />
      </mesh>
    </group>
  );
}
