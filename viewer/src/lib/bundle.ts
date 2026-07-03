import * as THREE from "three";

export interface ImageRef { file: string; width: number; height: number }
export interface DepthRef extends ImageRef { disparityMin: number; disparityMax: number }
export interface BundleManifest {
  formatVersion: 1;
  color: ImageRef;
  depth: DepthRef;
  matte?: ImageRef;
  source: { originalFilename: string; deviceModel?: string | null };
}
export interface LoadedBundle {
  manifest: BundleManifest;
  color: THREE.Texture;
  depth: THREE.Texture;
}

function isImageRef(v: unknown): v is ImageRef {
  const r = v as ImageRef;
  return !!r && typeof r.file === "string" && typeof r.width === "number" && typeof r.height === "number";
}

export function parseManifest(json: unknown): BundleManifest {
  const m = json as BundleManifest;
  if (!m || m.formatVersion !== 1) throw new Error("manifest: unsupported formatVersion (expected 1)");
  if (!isImageRef(m.color)) throw new Error("manifest: missing/invalid color");
  if (!isImageRef(m.depth) || typeof m.depth.disparityMin !== "number" || typeof m.depth.disparityMax !== "number")
    throw new Error("manifest: missing/invalid depth");
  if (m.matte !== undefined && !isImageRef(m.matte)) throw new Error("manifest: invalid matte");
  if (!m.source || typeof m.source.originalFilename !== "string") throw new Error("manifest: missing source");
  return m;
}

async function loadTexture(url: string): Promise<THREE.Texture> {
  const tex = await new THREE.TextureLoader().loadAsync(url);
  tex.colorSpace = THREE.NoColorSpace;
  tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
  return tex;
}

export async function loadBundle(baseUrl: string): Promise<LoadedBundle> {
  const res = await fetch(`${baseUrl}/manifest.json`);
  if (!res.ok) throw new Error(`bundle: cannot fetch ${baseUrl}/manifest.json (${res.status})`);
  const manifest = parseManifest(await res.json());
  const [color, depth] = await Promise.all([
    loadTexture(`${baseUrl}/${manifest.color.file}`),
    loadTexture(`${baseUrl}/${manifest.depth.file}`),
  ]);
  color.colorSpace = THREE.SRGBColorSpace;
  return { manifest, color, depth };
}

/** Canvas-generated demo so the viewer runs with zero assets: colored blocks + radial depth. */
export function syntheticBundle(): LoadedBundle {
  const size = 512;
  const colorCanvas = document.createElement("canvas");
  colorCanvas.width = colorCanvas.height = size;
  const c = colorCanvas.getContext("2d")!;
  c.fillStyle = "#2a4d69"; c.fillRect(0, 0, size, size);
  c.fillStyle = "#e8a33d"; c.fillRect(96, 96, 140, 140);
  c.fillStyle = "#d1495b"; c.beginPath(); c.arc(340, 330, 90, 0, Math.PI * 2); c.fill();
  c.fillStyle = "#fff"; c.font = "24px system-ui"; c.fillText("synthetic demo", 160, 480);

  const depthCanvas = document.createElement("canvas");
  depthCanvas.width = depthCanvas.height = size;
  const d = depthCanvas.getContext("2d")!;
  const g = d.createRadialGradient(340, 330, 20, 340, 330, 400);
  g.addColorStop(0, "#fff"); g.addColorStop(1, "#000");
  d.fillStyle = g; d.fillRect(0, 0, size, size);
  d.fillStyle = "#888"; d.fillRect(96, 96, 140, 140);

  const color = new THREE.CanvasTexture(colorCanvas);
  color.colorSpace = THREE.SRGBColorSpace;
  const depth = new THREE.CanvasTexture(depthCanvas);
  return {
    manifest: {
      formatVersion: 1,
      color: { file: "canvas", width: size, height: size },
      depth: { file: "canvas", width: size, height: size, disparityMin: 0, disparityMax: 1 },
      source: { originalFilename: "synthetic", deviceModel: null },
    },
    color, depth,
  };
}
