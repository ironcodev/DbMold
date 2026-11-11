// build.js
const { buildAll } = require("./scripts/build");

try {
  buildAll();
} catch (err) {
  console.error("ERROR:", err.message);
  process.exit(1);
}
