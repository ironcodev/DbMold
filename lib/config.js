const fs = require("fs");
const path = require("path");
const { promptForConfig } = require("./prompt");

const CONFIG_FILENAME = "dbmold.config.json";

function getConfigPath() {
  return path.resolve(process.cwd(), CONFIG_FILENAME);
}

function loadConfig() {
  const configPath = getConfigPath();
  if (!fs.existsSync(configPath)) {
    return null;
  }

  let config;
  try {
    config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  } catch (err) {
    throw new Error(`Failed to parse ${CONFIG_FILENAME}: ${err.message}`);
  }

  // Default server.
  if (!config.server) {
    config.server = "localhost";
  }

  if (!config.database) throw new Error(`${CONFIG_FILENAME}: "database" is required.`);
  if (!config.user) throw new Error(`${CONFIG_FILENAME}: "user" is required.`);
  if (!config.password) throw new Error(`${CONFIG_FILENAME}: "password" is required.`);

  // Normalize schema vs schemas.
  if (config.schemas && Array.isArray(config.schemas)) {
    // use as-is
  } else if (config.schema) {
    config.schemas = [config.schema];
  } else {
    config.schemas = ["mold"];
  }

  for (const s of config.schemas) {
    if (!["mold", "m"].includes(s)) {
      throw new Error(`${CONFIG_FILENAME}: invalid schema "${s}". Must be "mold" or "m".`);
    }
  }

  return config;
}

function saveConfig(config) {
  const configPath = getConfigPath();
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf8");
  console.log(`Config saved to ${CONFIG_FILENAME}`);
}

async function getConfig({ save = false } = {}) {
  const existing = loadConfig();
  if (existing) {
    console.log(`Using config from ${CONFIG_FILENAME}`);
    return existing;
  }

  const config = await promptForConfig();

  if (save) {
    saveConfig(config);
  }

  return config;
}

module.exports = { getConfig, loadConfig, saveConfig, CONFIG_FILENAME };
