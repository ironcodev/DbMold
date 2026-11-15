// lib/installer.js
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const { getConfig } = require("./config");
const { buildBaseConnectionArgs } = require("./connector");

function runSqlcmd(args) {
  return new Promise((resolve, reject) => {
    const child = spawn("sqlcmd", args, {
      stdio: ["ignore", "inherit", "inherit"],
    });

    child.on("error", (err) => {
      if (err.code === "ENOENT") {
        reject(
          new Error(
            "sqlcmd not found in PATH.\n" +
              'Install "SQL Server Command Line Utilities" and ensure sqlcmd is on PATH.\n' +
              "See: https://learn.microsoft.com/sql/tools/sqlcmd",
          ),
        );
      } else {
        reject(err);
      }
    });

    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`sqlcmd exited with code ${code}`));
    });
  });
}

async function installCommand({ configPath, env } = {}) {
  const config = await getConfig({ configPath, env });

  const schemas = config.schemas || ["mold"];

  const installScripts = schemas.map((schema) => {
    const p = path.resolve(process.cwd(), "dist", `install-${schema}.sql`);
    if (!fs.existsSync(p)) {
      throw new Error(
        `Install script not found: ${p}\n` +
          `Run "npm run build" first to generate dist/install-*.sql from src/.`,
      );
    }
    return { schema, path: p };
  });

  for (const { schema, path: scriptPath } of installScripts) {
    console.log(`\nInstalling schema "${schema}"...`);

    const args = buildBaseConnectionArgs(config);
    args.push("-i", scriptPath);
    args.push("-x");

    console.log(`> sqlcmd ${args.join(" ")}`);
    await runSqlcmd(args);
    console.log(`Schema "${schema}" installed successfully.`);
  }

  if (installScripts.length > 1) {
    console.log(`\nAll ${installScripts.length} schemas installed.`);
  }
}

module.exports = { installCommand };
