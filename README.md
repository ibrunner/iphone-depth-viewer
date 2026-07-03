# iphone-depth-viewer

Toolkit: extract iPhone Portrait-photo depth maps → process → view with parallax in the browser.

See [CLAUDE.md](CLAUDE.md) for layout, commands, and conventions.
See [docs/superpowers/specs/2026-07-03-depth-viewer-toolkit-design.md](docs/superpowers/specs/2026-07-03-depth-viewer-toolkit-design.md) for spec.

## Photo → wiggle on your iPhone

1. Shoot a Portrait-mode photo. AirDrop it to this Mac (or Photos → File → Export → Export Unmodified Original).
2. Extract: `cd extract && swift run depth-extract ~/Downloads/IMG_1234.heic -o ../viewer/public/bundles`
3. Serve: `cd viewer && npm run dev` — note the `https://192.168.x.x:5173` Network URL.
4. On the iPhone (same Wi-Fi), open that URL in Safari. Accept the self-signed-certificate warning
   (Advanced → proceed). Then open `https://192.168.x.x:5173/?bundle=IMG_1234`.
5. Tap **Enable gyro parallax** and grant motion access. Wiggle the phone.

Notes: the neutral pose is captured the moment you tap the button — hold the phone how you
intend to view it, then tap. Reload to re-baseline.
