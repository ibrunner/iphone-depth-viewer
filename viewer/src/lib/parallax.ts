import * as THREE from "three";
import type { LoadedBundle } from "./bundle";

const vertexShader = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const fragmentShader = /* glsl */ `
  uniform sampler2D uColor;
  uniform sampler2D uDepth;
  uniform vec2 uOffset;     // eye offset, [-1,1]
  uniform float uStrength;  // parallax strength in UV units
  varying vec2 vUv;
  void main() {
    // Two-tap: sample depth at the shifted location too, reduces edge halos a bit.
    float d0 = texture2D(uDepth, vUv).r;
    vec2 shift = uOffset * uStrength * (d0 - 0.5);
    float d1 = texture2D(uDepth, vUv + shift).r;
    vec2 uv = vUv + uOffset * uStrength * (d1 - 0.5);
    gl_FragColor = texture2D(uColor, clamp(uv, 0.0, 1.0));
  }
`;

export interface ParallaxScene {
  setOffset(x: number, y: number): void;
  dispose(): void;
}

export function createParallaxScene(canvas: HTMLCanvasElement, bundle: LoadedBundle): ParallaxScene {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

  const uniforms = {
    uColor: { value: bundle.color },
    uDepth: { value: bundle.depth },
    uOffset: { value: new THREE.Vector2(0, 0) },
    uStrength: { value: 0.04 },
  };
  const target = new THREE.Vector2(0, 0);
  const quad = new THREE.Mesh(
    new THREE.PlaneGeometry(2, 2),
    new THREE.ShaderMaterial({ uniforms, vertexShader, fragmentShader })
  );
  scene.add(quad);

  const aspect = bundle.manifest.color.width / bundle.manifest.color.height;
  function resize() {
    const w = canvas.clientWidth, h = Math.round(canvas.clientWidth / aspect);
    renderer.setSize(w, h, false);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  }
  resize();
  window.addEventListener("resize", resize);

  let raf = 0;
  function frame() {
    // Ease toward the target so gyro jitter doesn't shake the image.
    uniforms.uOffset.value.lerp(target, 0.15);
    renderer.render(scene, camera);
    raf = requestAnimationFrame(frame);
  }
  frame();

  return {
    setOffset(x, y) { target.set(x, y); },
    dispose() {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      quad.geometry.dispose();
      (quad.material as THREE.Material).dispose();
      bundle.color.dispose();
      bundle.depth.dispose();
      renderer.dispose();
    },
  };
}
