import { useEffect, useRef, useState } from "react";
import { loadBundle, syntheticBundle, type LoadedBundle } from "../lib/bundle";
import { createParallaxScene, type ParallaxScene } from "../lib/parallax";
import { attachMouseInput, attachGyroInput, gyroAvailable } from "../lib/inputs";

export default function ParallaxViewer({ bundleUrl }: { bundleUrl: string | null }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const sceneRef = useRef<ParallaxScene | null>(null);
  const [status, setStatus] = useState("loading…");

  useEffect(() => {
    let disposed = false;
    let detach = () => {};
    (async () => {
      let bundle: LoadedBundle;
      try {
        bundle = bundleUrl ? await loadBundle(bundleUrl) : syntheticBundle();
        setStatus(bundleUrl ? bundle.manifest.source.originalFilename : "synthetic demo (add ?bundle=<name>)");
      } catch (e) {
        bundle = syntheticBundle();
        setStatus(`failed to load ${bundleUrl}: ${(e as Error).message} — showing synthetic demo`);
      }
      if (disposed || !canvasRef.current) return;
      const scene = createParallaxScene(canvasRef.current, bundle);
      sceneRef.current = scene;
      detach = attachMouseInput(canvasRef.current, (x, y) => scene.setOffset(x, y));
    })();
    return () => { disposed = true; detach(); sceneRef.current?.dispose(); sceneRef.current = null; };
  }, [bundleUrl]);

  const [gyro, setGyro] = useState<"off" | "on" | "error">("off");
  const gyroDetach = useRef<() => void>(() => {});

  async function enableGyro() {
    try {
      gyroDetach.current = await attachGyroInput((x, y) => sceneRef.current?.setOffset(x, y));
      setGyro("on");
    } catch (e) {
      setStatus((e as Error).message);
      setGyro("error");
    }
  }
  useEffect(() => () => gyroDetach.current(), []);

  return (
    <div>
      <canvas ref={canvasRef} style={{ width: "100%", display: "block", touchAction: "none" }} />
      <p style={{ fontFamily: "system-ui", padding: "0 8px" }}>{status}</p>
      {gyroAvailable() && gyro !== "on" && (
        <button onClick={enableGyro} style={{ margin: 8, padding: "12px 20px", fontSize: 16 }}>
          Enable gyro parallax
        </button>
      )}
    </div>
  );
}
