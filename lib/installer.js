const fs = require("fs");
const path = require("path");
const sql = require("mssql");
const { getConfig } = require("./config");

/**
 * Split a SQL script into batches on GO lines.
 * GO must be alone on its line (case-insensitive, optional whitespace).
 */
function splitOnGo(script) {
  return script
    .split(/^\s*GO\s*$/im)
    .map((b) => b.trim())
    .filter((b) => b.length > 0);
}

function buildConnectionConfig(config) {
  const conn = {
    server: config.server,
    database: config.database,
    options: config.options || {
      encrypt: false,
      trustServerCertificate: true,
    },
  };

  if (config.user) {
    conn.user = config.user;
    conn.password = config.password;
  }

  return conn;
}

async function installCommand() {
  const config = await getConfig();

  const schemas = config.schemas || ["mold"];

  // Pre-check all install scripts exist.
  const installScripts = schemas.map((schema) => {
    const p = path.resolve(process.cwd(), "dist", `install-${schema}.sql`);
    if (!fs.existsSync(p)) {
      throw new Error(
        `Install script not found: ${p}\n` + `Run "npm run build" first to generate dist/install-*.sql from src/.`,
      );
    }
    return { schema, path: p };
  });

  // Read and split all scripts up front.
  const jobs = installScripts.map(({ schema, path: p }) => {
    const batches = splitOnGo(fs.readFileSync(p, "utf8"));
    if (batches.length === 0) {
      throw new Error(`Install script is empty: ${p}`);
    }
    return { schema, batches };
  });

  console.log(`\nConnecting to ${config.server}/${config.database}...`);
  const pool = await sql.connect(buildConnectionConfig(config));

  try {
    for (const { schema, batches } of jobs) {
      console.log(`\nInstalling schema "${schema}" (${batches.length} batches)...`);

      for (let i = 0; i < batches.length; i++) {
        try {
          await pool.request().batch(batches[i]);
        } catch (err) {
          throw new Error(
            `Schema "${schema}", batch ${i + 1}/${batches.length} failed: ${err.message}\n` +
              `Batch content:\n${batches[i].slice(0, 500)}...`,
          );
        }
      }

      console.log(`Schema "${schema}" installed successfully.`);
    }

    if (jobs.length > 1) {
      console.log(`\nAll ${jobs.length} schemas installed.`);
    }
  } finally {
    await pool.close();
  }
}

module.exports = { installCommand };
