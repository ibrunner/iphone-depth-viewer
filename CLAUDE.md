# iphone-depth-viewer

Toolkit: extract iPhone Portrait-photo depth maps → process → view with parallax in the browser.
Spec: docs/superpowers/specs/2026-07-03-depth-viewer-toolkit-design.md
Plans: docs/superpowers/plans/

## Layout
- `extract/` — Swift package (macOS). `depth-extract` CLI: Portrait HEIC → depth bundle.
- `pipeline/` — Python + ComfyUI workflows enriching bundles (M3, not built yet).
- `viewer/` — Vite + React + three.js parallax viewer.
- `samples/` — local Portrait HEICs for testing (gitignored; see samples/README.md).

## The depth bundle (contract between layers)
Directory: `manifest.json` + `color.png` + `depth.png` (16-bit gray, normalized disparity)
+ optional `matte.png`. Manifest schema lives in extract/Sources/DepthExtractKit/BundleManifest.swift
and viewer/src/lib/bundle.ts — keep them in sync.

## Commands
- Extractor build/test: `cd extract && swift build && swift test`
- Extract: `cd extract && swift run depth-extract ~/photo.heic -o ../viewer/public/bundles`
- Viewer dev: `cd viewer && npm run dev` (HTTPS on LAN for iPhone: same command, accept cert on phone)
- Viewer tests: `cd viewer && npx vitest run`

## Conventions
- Proof-of-concept bar; prefer simple over robust, but extractor errors must be clear.
- TDD where tests are cheap (pure logic); manual verification for GPU/browser behavior.
