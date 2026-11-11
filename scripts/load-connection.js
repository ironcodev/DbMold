// scripts/load-connection.js
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");

function loadConnection() {
  const basePath = path.join(ROOT, "connection.json");
  const devPath = path.join(ROOT, "connection.dev.json");

  if (!fs.existsSync(basePath)) {
    throw new Error(
      "connection.json not found. Copy connection.example.json and edit it.",
    );
  }

  const base = JSON.parse(fs.readFileSync(basePath, "utf8"));
  let dev = {};
  if (fs.existsSync(devPath)) {
    dev = JSON.parse(fs.readFileSync(devPath, "utf8"));
  }

  const merged = { ...base, ...dev };

  if (!merged.server) throw new Error("connection: server is required");
  if (!merged.database) throw new Error("connection: database is required");

  return merged;
}

module.exports = { loadConnection };
