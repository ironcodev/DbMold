// scripts/run-sqlcmd.js
const { spawn } = require("child_process");
const { loadConnection } = require("./load-connection");

function buildSqlcmdArgs(conn, scriptFile, extraVars, dbOverride) {
  const database = dbOverride || conn.database;
  const args = ["-S", conn.server, "-d", database, "-b", "-i", scriptFile];

  if (conn.user && conn.password) {
    args.push("-U", conn.user, "-P", conn.password);
  } else {
    args.push("-E");
  }

  if (conn.trustServerCertificate) args.push("-C");
  if (conn.encrypt === false) args.push("-N", "O");

  for (const [k, v] of Object.entries(extraVars || {})) {
    args.push("-v", `${k}="${v}"`);
  }

  return args;
}

function runSqlcmd(conn, scriptFile, extraVars, dbOverride) {
  return new Promise((resolve, reject) => {
    const args = buildSqlcmdArgs(conn, scriptFile, extraVars, dbOverride);
    console.log(`> sqlcmd ${args.join(" ")}`);

    const child = spawn("sqlcmd", args, { stdio: "inherit" });

    child.on("error", (err) => {
      if (err.code === "ENOENT") {
        reject(
          new Error(
            'sqlcmd not found in PATH. Install "SQL Server Command Line Utilities".',
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

module.exports = { runSqlcmd };
