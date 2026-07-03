export type OffsetCallback = (x: number, y: number) => void;

/** Pointer position relative to element center → offset in [-1, 1]. Returns detach fn. */
export function attachMouseInput(el: HTMLElement, onOffset: OffsetCallback): () => void {
  const onMove = (e: PointerEvent) => {
    const r = el.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width) * 2 - 1;
    const y = ((e.clientY - r.top) / r.height) * 2 - 1;
    onOffset(Math.max(-1, Math.min(1, x)), Math.max(-1, Math.min(1, -y)));
  };
  el.addEventListener("pointermove", onMove);
  return () => el.removeEventListener("pointermove", onMove);
}

interface IOSOrientationEvent { requestPermission?: () => Promise<"granted" | "denied"> }

export function gyroAvailable(): boolean {
  return typeof window !== "undefined" && "DeviceOrientationEvent" in window;
}

/** Tilt relative to the pose when attached. ±RANGE degrees maps to [-1, 1]. */
export async function attachGyroInput(onOffset: OffsetCallback): Promise<() => void> {
  if (!gyroAvailable()) throw new Error("DeviceOrientation not supported");
  const ctor = DeviceOrientationEvent as unknown as IOSOrientationEvent;
  if (typeof ctor.requestPermission === "function") {
    const result = await ctor.requestPermission();
    if (result !== "granted") throw new Error("Motion permission denied");
  }
  const RANGE = 15; // degrees of tilt for full parallax
  let base: { beta: number; gamma: number } | null = null;
  const onOrient = (e: DeviceOrientationEvent) => {
    if (e.beta == null || e.gamma == null) return;
    if (!base) base = { beta: e.beta, gamma: e.gamma };
    const x = Math.max(-1, Math.min(1, (e.gamma - base.gamma) / RANGE));
    const y = Math.max(-1, Math.min(1, (e.beta - base.beta) / RANGE));
    onOffset(x, -y);
  };
  window.addEventListener("deviceorientation", onOrient);
  return () => window.removeEventListener("deviceorientation", onOrient);
}
