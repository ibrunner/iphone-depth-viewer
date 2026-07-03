import { test, expect } from "@playwright/test";

test("mouse parallax shifts rendered pixels", async ({ page }) => {
  await page.goto("/"); // no ?bundle= — synthetic demo, zero assets needed
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const box = (await canvas.boundingBox())!;

  await page.mouse.move(box.x + 10, box.y + 10);
  await page.waitForTimeout(600); // let the eased offset settle
  const before = await canvas.screenshot();

  await page.mouse.move(box.x + box.width - 10, box.y + box.height - 10);
  await page.waitForTimeout(600);
  const after = await canvas.screenshot();

  expect(before.equals(after)).toBe(false);
});
