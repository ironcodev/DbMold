// lib/connector.js
const { spawn } = require("child_process");
const { getConfig } = require("./config");

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

function buildBaseConnectionArgs(config) {
  const args = [
    "-S",
    config.server || "localhost",
    "-d",
    config.database,
    "-b",
    "-r",
    "1",
  ];

  if (config.trustedConnection === true) {
    args.push("-E");
  } else {
    args.push("-U", config.user, "-P", config.password);
  }

  if (config.encrypt === false) {
    args.push("-N", "O");
  }

  if (config.trustServerCertificate === true) {
    args.push("-C");
  }

  return args;
}

async function connectCommand({ configPath, env } = {}) {
  const config = await getConfig({ configPath, env });

  const query = "SET NOCOUNT ON; SELECT @@VERSION AS version;";
  const args = buildBaseConnectionArgs(config);
  args.push("-Q", query);

  console.log(
    `\nTesting connection to ${config.server || "localhost"}/${config.database}...`,
  );

  try {
    await runSqlcmd(args);
    console.log("\nConnection OK.");
  } catch (err) {
    throw new Error("Connection failed. See the message above for details.");
  }
}

module.exports = { connectCommand, buildBaseConnectionArgs };
