// Eager-load all controllers in this directory (esbuild flavour).
const controllers = import.meta.glob("./**/*_controller.js", { eager: true })

import { application } from "./application"

for (const [path, controller] of Object.entries(controllers)) {
  if (path.endsWith("_controller.js")) {
    const name = path
      .replace(/^\.\/|\.js$/g, "")
      .replace(/_controller$/, "")
      .replace(/\//g, "--")
    application.register(name, controller.default)
  }
}
