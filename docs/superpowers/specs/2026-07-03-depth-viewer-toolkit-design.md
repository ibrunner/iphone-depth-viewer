# iPhone Depth Viewer Toolkit — Design

**Date:** 2026-07-03
**Status:** Approved design, pre-implementation
**Scope:** Proof-of-concept, garage-scale. Single developer on macOS. No hosting, multi-user, or scalability concerns.

## Goal

Take iPhone Portrait-mode photos, extract their embedded depth data, optionally enrich it through a ComfyUI processing pipeline, and view the result in a web-based WebGL viewer with a parallax effect — wiggle the phone (gyro) or move the mouse and see the photo shift in depth. Stretch goal: interactive lighting.

## Key research findings

- **No custom capture app is needed.** Portrait-mode HEIC files embed a depth map (disparity, ~320×240 up to ~768×576) and, for photos of people, a higher-resolution portrait effects matte, as HEIF auxiliary images. Extractable via ImageIO (Swift), libheif, or exiftool.
- **Depth generation differs by camera:** front-camera portraits use the TrueDepth (Face ID) structured-light sensor — clean close-range depth, flat backgrounds; rear-camera portraits use stereo disparity between lenses, LiDAR-assisted on Pro models — full-scene coverage with soft edges. Golden test files should include one of each.
- **Prior art validates the approach:** Depthy (WebGL quad + UV-offset shader), DepthFlow (ray-marched parallax), Facebook 3D photos (layered depth mesh), Apple's own iOS 26 "spatial scenes."
- **ComfyUI ecosystem covers the pipeline needs:** Depth Anything V2 (depth refinement), inpainting (occlusion fill), IC-Light (relighting), normal-map generation nodes.

## Architecture

Three layers joined by one versioned asset format:

```
Portrait HEIC ──▶ [1] extract/ (Swift CLI) ──▶ depth bundle ──▶ [3] viewer/ (React+WebGL)
                                                    │                    ▲
                                                    ▼                    │
                                     [2] pipeline/ (Python + ComfyUI) ───┘
                                          refined/layered viewer asset
```

### The depth bundle (the contract)

A versioned directory format every layer reads/writes. Extractors produce v1; the pipeline enriches to v2 additively; the viewer feature-detects what's present and renders the richest mode it can.

**Bundle v1 (raw extraction):**

```
my-photo/
  manifest.json    # format version, dimensions, disparity min/max,
                   # source metadata (camera, capture device, original filename)
  color.png        # full-res photo
  depth.png        # 16-bit grayscale PNG, normalized disparity
  matte.png        # portrait effects matte (present only for photos of people)
```

**Bundle v2 (pipeline-enriched, additive):** refined high-res `depth.png`, layer entries (per-layer color+alpha texture and depth range, occlusion-inpainted), and later `normal.png` and/or baked relight views. The manifest describes which assets exist.

### 1. extract/ — Swift CLI (macOS)

`depth-extract`: a small command-line tool on ImageIO/CoreImage — the most faithful access to Apple's auxiliary images. Input: one HEIC or a folder (batch). Output: depth bundle(s).

Error handling: the #1 expected user error is a HEIC with no depth data (non-portrait photo) — fail with a clear message naming the file and the reason. Distinguish "no aux depth image" from "unreadable file."

### 2. pipeline/ — Python + ComfyUI

Checked-in ComfyUI workflow JSONs plus Python helper scripts that operate on bundles:

- **Refine/upscale depth** — use the native (metric-anchored) depth to guide a Depth Anything V2 pass, producing high-res depth that respects real measurements.
- **Layer split** — quantize depth into 2–4 layers, using the matte for the subject cut.
- **Occlusion inpaint** — inpaint behind each layer so parallax reveals real pixels instead of stretching.
- **Stretch:** normal-map generation; IC-Light relight bakes at several light angles.

### 3. viewer/ — React + three.js (Vite)

three.js over raw WebGL: the MVP shader is simple either way, but layer stacking and the lighting stretch goals get much cheaper with a scene graph.

Renderer evolves in place:

- **MVP:** single quad, UV-offset-by-depth GLSL shader (Depthy technique), mouse-driven parallax. Loads a v1 bundle; a demo bundle is checked in so the viewer runs standalone.
- **Gyro:** DeviceOrientation input on iPhone Safari. Requires HTTPS and a user-gesture permission prompt — its own milestone.
- **Layers:** stacked planes with real occlusion reveal when a v2 bundle is loaded.
- **Stretch lighting:** movable light + normal map, and/or crossfading baked IC-Light views, driven by the same tilt/mouse input.

## Milestones

| # | Deliverable | Proves |
|---|---|---|
| M0 | Repo scaffold: CLAUDE.md, docs, directory layout, sample HEICs | — |
| M1 (MVP) | Swift extractor + viewer with mouse parallax on raw depth | End-to-end: shoot → extract → wiggle |
| M2 | Gyro parallax on iPhone Safari (HTTPS dev serving, permission UX) | The "wiggle my phone" moment |
| M3 | ComfyUI pipeline (refine, layers, occlusion) + layered renderer | The quality leap |
| M4 (stretch) | Lighting: normal maps and/or baked relight blending | Interactive lighting |

## Testing

- **Extractor:** golden sample HEICs committed to the repo — one rear-camera portrait, one front-camera (TrueDepth) selfie portrait, one depthless negative case. Tests assert bundle structure and manifest contents.
- **Viewer:** manual testing against the checked-in demo bundle; optional Playwright screenshot checks later.
- **Pipeline:** eyeball validation of workflow outputs; light smoke tests on helper scripts.

## User Flows (E2E-tested)

| ID | Flow | Phase visible | Spec test |
|----|------|--------------|-----------|
| UF-1 | Open the viewer, move the mouse over the image — it parallaxes | Phase 3 | `"mouse parallax shifts rendered pixels"` |
| UF-2 | On iPhone Safari: open viewer over LAN HTTPS, enable gyro, tilt the phone — the photo parallaxes | Phase 4 | manual on-device (gyro is not automatable) |

## Backlog (explicitly deferred)

- **Spatial photo stereo extraction** — iPhone 15 Pro+ / Vision Pro spatial photos hold a full-resolution stereo pair (no depth map). A second extractor would pull the pair and compute depth via stereo matching. Chief value: high-resolution depth for scenes Portrait mode handles poorly (e.g., landscapes). The bundle format is designed so this slots in as another v1 producer.
- Custom iOS capture app (full-precision LiDAR/TrueDepth capture or streaming — Record3D already covers much of this).
- Video / live depth streams.
- Hosting, auth, multi-user anything.

## Decisions log

- Portrait HEIC as primary input (user-confirmed).
- Swift for extraction, Python for pipeline, React+WebGL for client; pragmatic layered prototyping (user-confirmed).
- Displaced-quad-evolving-to-layers renderer (recommended default; chosen when the renderer question went unanswered — revisit if desired).
