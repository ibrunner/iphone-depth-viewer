import { useEffect, useRef, useState } from "react";
import { loadBundle, syntheticBundle, type LoadedBundle } from "../lib/bundle";
import { createParallaxScene, type ParallaxScene } from "../lib/parallax";
import { attachMouseInput } from "../lib/inputs";

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

  return (
    <div>
      <canvas ref={canvasRef} style={{ width: "100%", display: "block", touchAction: "none" }} />
      <p style={{ fontFamily: "system-ui", padding: "0 8px" }}>{status}</p>
    </div>
  );
}
