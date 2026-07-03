import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "e2e",
  use: { baseURL: "https://localhost:5181", ignoreHTTPSErrors: true },
  webServer: {
    command: "npm run dev -- --port 5181",
    url: "https://localhost:5181",
    ignoreHTTPSErrors: true,
    reuseExistingServer: true,
  },
});
