import { describe, it, expect } from "vitest";
import { parseManifest } from "./bundle";

const valid = {
  formatVersion: 1,
  color: { file: "color.png", width: 4032, height: 3024 },
  depth: { file: "depth.png", width: 768, height: 576, disparityMin: 0.01, disparityMax: 2.2 },
  source: { originalFilename: "IMG_1.heic", deviceModel: "iPhone 15 Pro" },
};

describe("parseManifest", () => {
  it("accepts a valid v1 manifest without matte", () => {
    expect(parseManifest(valid).depth.width).toBe(768);
    expect(parseManifest(valid).matte).toBeUndefined();
  });
  it("accepts an optional matte", () => {
    const m = parseManifest({ ...valid, matte: { file: "matte.png", width: 10, height: 10 } });
    expect(m.matte?.file).toBe("matte.png");
  });
  it("rejects unknown formatVersion", () => {
    expect(() => parseManifest({ ...valid, formatVersion: 2 })).toThrow(/formatVersion/);
  });
  it("rejects missing depth", () => {
    const { depth: _d, ...noDepth } = valid;
    expect(() => parseManifest(noDepth)).toThrow(/depth/);
  });
});
