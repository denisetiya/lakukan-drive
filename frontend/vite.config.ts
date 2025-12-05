import path from "node:path";
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import VueI18nPlugin from "@intlify/unplugin-vue-i18n/vite";
import legacy from "@vitejs/plugin-legacy";
import { compression } from "vite-plugin-compression2";

const plugins = [
  vue(),
  VueI18nPlugin({
    include: [path.resolve(__dirname, "./src/i18n/**/*.json")],
  }),
  legacy({
    // defaults already drop IE support
    targets: ["defaults"],
  }),
  compression({ include: /\.js$/i, deleteOriginalAssets: true }),
];

const resolve = {
  alias: {
    // vue: "@vue/compat",
    "@/": `${path.resolve(__dirname, "src")}/`,
  },
};

// https://vitejs.dev/config/
export default defineConfig(({ command }) => {
  if (command === "serve") {
    const backendUrl = process.env.BACKEND_URL || "http://127.0.0.1:8080";
    const backendWsUrl = process.env.BACKEND_WS_URL || "ws://127.0.0.1:8080";

    // Debug logging
    console.log("Environment variables:");
    console.log("BACKEND_URL:", process.env.BACKEND_URL);
    console.log("BACKEND_WS_URL:", process.env.BACKEND_WS_URL);
    console.log("Using backend URL:", backendUrl);
    console.log("Using backend WS URL:", backendWsUrl);

    return {
      plugins,
      resolve,
      server: {
        host: "0.0.0.0",
        allowedHosts: ["drive.lakukan.co.id", "localhost", "127.0.0.1"],
        proxy: {
          "/api/command": {
            target: backendWsUrl,
            ws: true,
          },
          "/api": backendUrl,
        },
      },
    };
  } else {
    // command === 'build'
    return {
      plugins,
      resolve,
      base: "",
      build: {
        rollupOptions: {
          input: {
            index: path.resolve(__dirname, "./public/index.html"),
          },
          external: (id) => {
            // Keep reCAPTCHA script external - it will be loaded at runtime
            return (
              id.includes("recaptcha/api.js") ||
              id.includes("[{[ .ReCaptchaHost ]}]")
            );
          },
          output: {
            manualChunks: (id) => {
              // bundle dayjs files in a single chunk
              // this avoids having small files for each locale
              if (id.includes("dayjs/")) {
                return "dayjs";
                // bundle i18n in a separate chunk
              } else if (id.includes("i18n/")) {
                return "i18n";
              }
            },
          },
        },
      },
      experimental: {
        renderBuiltUrl(filename, { hostType }) {
          if (hostType === "js") {
            return { runtime: `window.__prependStaticUrl("${filename}")` };
          } else if (hostType === "html") {
            return `[{[ .StaticURL ]}]/${filename}`;
          } else {
            return { relative: true };
          }
        },
      },
    };
  }
});
