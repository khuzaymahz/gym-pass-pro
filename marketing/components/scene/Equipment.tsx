"use client";

import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";

function Dumbbell({
  position,
  phase,
}: {
  position: [number, number, number];
  phase: number;
}) {
  const ref = useRef<THREE.Group>(null);
  useFrame((state) => {
    if (!ref.current) return;
    const t = state.clock.elapsedTime;
    ref.current.rotation.x = t * 0.4 + phase;
    ref.current.rotation.y = t * 0.6 + phase;
    ref.current.position.y = position[1] + Math.sin(t * 0.8 + phase) * 0.3;
  });

  return (
    <group ref={ref} position={position}>
      <mesh>
        <cylinderGeometry args={[0.08, 0.08, 1.4, 24]} />
        <meshStandardMaterial color="#1E2221" metalness={0.8} roughness={0.25} />
      </mesh>
      <mesh position={[0, 0.85, 0]}>
        <sphereGeometry args={[0.32, 32, 32]} />
        <meshStandardMaterial color="#2A2E2C" metalness={0.9} roughness={0.2} />
      </mesh>
      <mesh position={[0, -0.85, 0]}>
        <sphereGeometry args={[0.32, 32, 32]} />
        <meshStandardMaterial color="#2A2E2C" metalness={0.9} roughness={0.2} />
      </mesh>
    </group>
  );
}

function Kettlebell({
  position,
  phase,
}: {
  position: [number, number, number];
  phase: number;
}) {
  const ref = useRef<THREE.Group>(null);
  useFrame((state) => {
    if (!ref.current) return;
    const t = state.clock.elapsedTime;
    ref.current.rotation.z = Math.sin(t * 0.5 + phase) * 0.35;
    ref.current.position.y = position[1] + Math.cos(t * 0.7 + phase) * 0.25;
  });

  return (
    <group ref={ref} position={position}>
      <mesh>
        <sphereGeometry args={[0.45, 32, 32]} />
        <meshStandardMaterial color="#171A19" metalness={0.7} roughness={0.35} />
      </mesh>
      <mesh position={[0, 0.5, 0]}>
        <torusGeometry args={[0.18, 0.055, 16, 32, Math.PI]} />
        <meshStandardMaterial color="#1E2221" metalness={0.8} roughness={0.3} />
      </mesh>
    </group>
  );
}

function Plate({
  position,
  phase,
}: {
  position: [number, number, number];
  phase: number;
}) {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((state) => {
    if (!ref.current) return;
    const t = state.clock.elapsedTime;
    ref.current.rotation.x = t * 0.3 + phase;
    ref.current.rotation.y = t * 0.2 + phase;
  });

  return (
    <mesh ref={ref} position={position}>
      <torusGeometry args={[0.55, 0.12, 16, 48]} />
      <meshStandardMaterial
        color="#BBFB46"
        emissive="#7FA82E"
        emissiveIntensity={0.15}
        metalness={0.4}
        roughness={0.4}
      />
    </mesh>
  );
}

export function Equipment({ progress }: { progress: number }) {
  const group = useRef<THREE.Group>(null);
  useFrame(() => {
    if (!group.current) return;
    group.current.position.y = progress * -2.2;
    group.current.rotation.y = progress * Math.PI * 0.5;
  });

  return (
    <group ref={group}>
      <Dumbbell position={[-4, 1.2, -2]} phase={0} />
      <Dumbbell position={[4.2, -0.8, -1]} phase={1.7} />
      <Kettlebell position={[-3.2, -1.4, 1]} phase={0.9} />
      <Kettlebell position={[3.5, 1.8, 0.5]} phase={2.3} />
      <Plate position={[-2.2, 2.2, -3]} phase={0.5} />
      <Plate position={[2.6, -2.4, -2]} phase={2.8} />
    </group>
  );
}
