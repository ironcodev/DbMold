// scripts/install.js
const path = require("path");
const { loadConnection } = require("./load-connection");
const { runSqlcmd } = require("./run-sqlcmd");

async function main() {
  const schema = process.argv[2];
  if (!["mold", "x"].includes(schema)) {
    console.error("Usage: node scripts/install.js <mold|x>");
    process.exit(1);
  }

  const conn = loadConnection();
  const scriptPath = path.resolve(
    __dirname,
    "..",
    "dist",
    `install-${schema}.sql`,
  );

  console.log(
    `Installing schema "${schema}" into ${conn.server}/${conn.database}...`,
  );
  await runSqlcmd(conn, scriptPath);
  console.log("Installed.");
}

main().catch((err) => {
  console.error("ERROR:", err.message);
  process.exit(1);
});
