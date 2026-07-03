import ParallaxViewer from "./components/ParallaxViewer";

export default function App() {
  const name = new URLSearchParams(window.location.search).get("bundle");
  return <ParallaxViewer bundleUrl={name ? `/bundles/${name}` : null} />;
}
