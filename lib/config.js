// lib/config.js
const fs = require("fs");
const path = require("path");
const { promptForConfig } = require("./prompt");

const DEFAULT_CONFIG_FILENAME = "dbmold.config.json";

/**
 * Resolve a config path relative to cwd.
 */
function resolveConfigPath(filenameOrPath) {
  if (!filenameOrPath) {
    return path.resolve(process.cwd(), DEFAULT_CONFIG_FILENAME);
  }
  return path.resolve(process.cwd(), filenameOrPath);
}

/**
 * Given a base config filename (e.g. "dbmold.config.json"),
 * return the env-specific filename (e.g. "dbmold.config.prod.json").
 *
 * If the base filename does not end in ".json", ".json" is appended
 * before inserting the env.
 *
 * Examples:
 *   dbmold.config.json         + prod -> dbmold.config.prod.json
 *   mydbmold.config.json       + dev  -> mydbmold.config.dev.json
 *   config.json                + prod -> config.prod.json
 *   config                     + prod -> config.prod.json
 */
function envConfigPath(basePath, env) {
  if (!env) return null;

  const dir = path.dirname(basePath);
  const base = path.basename(basePath);

  let stem;
  if (base.toLowerCase().endsWith(".json")) {
    stem = base.slice(0, -".json".length);
  } else {
    stem = base;
  }

  const envFile = `${stem}.${env}.json`;
  return path.join(dir, envFile);
}

function deepMerge(base, override) {
  // Shallow merge is enough for our config shape, but be safe:
  // objects are merged recursively; arrays and primitives are replaced.
  const result = { ...base };
  for (const [k, v] of Object.entries(override)) {
    if (
      v &&
      typeof v === "object" &&
      !Array.isArray(v) &&
      result[k] &&
      typeof result[k] === "object" &&
      !Array.isArray(result[k])
    ) {
      result[k] = deepMerge(result[k], v);
    } else {
      result[k] = v;
    }
  }
  return result;
}

function readJsonFile(filePath, label) {
  let raw;
  try {
    raw = fs.readFileSync(filePath, "utf8");
  } catch (err) {
    throw new Error(`Failed to read ${label}: ${err.message}`);
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    throw new Error(`Failed to parse ${label}: ${err.message}`);
  }
}

function validateConfig(config, label) {
  if (!config.database) throw new Error(`${label}: "database" is required.`);

  if (config.trustedConnection !== true) {
    if (!config.user)
      throw new Error(
        `${label}: "user" is required when trustedConnection is false.`,
      );
    if (!config.password)
      throw new Error(
        `${label}: "password" is required when trustedConnection is false.`,
      );
  }

  if (config.schemas && Array.isArray(config.schemas)) {
    // use as-is
  } else if (config.schema) {
    config.schemas = [config.schema];
  } else {
    config.schemas = ["mold"];
  }

  for (const s of config.schemas) {
    if (!["mold", "m"].includes(s)) {
      throw new Error(
        `${label}: invalid schema "${s}". Must be "mold" or "m".`,
      );
    }
  }

  if (!config.server) config.server = "localhost";
  if (typeof config.trustedConnection !== "boolean")
    config.trustedConnection = false;
  if (typeof config.trustServerCertificate !== "boolean")
    config.trustServerCertificate = true;
  if (typeof config.encrypt !== "boolean") config.encrypt = false;

  return config;
}

/**
 * Load a config file and (if env is set and the env-specific file exists)
 * merge it on top.
 *
 * If the base file does not exist, returns null (unless the caller passed
 * an explicit path, which is handled in getConfig).
 */
function loadConfig(filenameOrPath, env) {
  const basePath = resolveConfigPath(filenameOrPath);

  if (!fs.existsSync(basePath)) {
    return null;
  }

  const baseLabel = filenameOrPath || DEFAULT_CONFIG_FILENAME;
  const base = readJsonFile(basePath, baseLabel);

  let merged = base;

  if (env) {
    const envPath = envConfigPath(basePath, env);
    if (fs.existsSync(envPath)) {
      const envLabel = path.basename(envPath);
      const envCfg = readJsonFile(envPath, envLabel);
      merged = deepMerge(base, envCfg);
    }
  }

  return validateConfig(merged, baseLabel);
}

function saveConfig(config, filenameOrPath) {
  const configPath = resolveConfigPath(filenameOrPath);
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf8");
  console.log(`Config saved to ${filenameOrPath || DEFAULT_CONFIG_FILENAME}`);
}

async function getConfig({ configPath, env } = {}) {
  if (configPath) {
    const config = loadConfig(configPath, env);
    if (!config) {
      throw new Error(`Config file not found: ${configPath}`);
    }
    const suffix = env ? ` (env: ${env})` : "";
    console.log(`Using config from ${configPath}${suffix}`);
    return config;
  }

  const existing = loadConfig(null, env);
  if (existing) {
    const suffix = env ? ` (env: ${env})` : "";
    console.log(`Using config from ${DEFAULT_CONFIG_FILENAME}${suffix}`);
    return existing;
  }

  const { config, save, filename } = await promptForConfig();

  if (save) {
    saveConfig(config, filename);
  }

  return config;
}

module.exports = {
  getConfig,
  loadConfig,
  saveConfig,
  validateConfig,
  resolveConfigPath,
  envConfigPath,
  deepMerge,
  DEFAULT_CONFIG_FILENAME,
};
