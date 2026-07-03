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
