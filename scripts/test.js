// scripts/test.js
const path = require("path");
const { loadConnection } = require("./load-connection");
const { runSqlcmd } = require("./run-sqlcmd");
const { buildAll, SCHEMAS } = require("./build");

async function main() {
  const conn = loadConnection();
  const root = path.resolve(__dirname, "..");

  // Safety guard: refuse to run against non-test databases.
  if (!conn.database.toLowerCase().endsWith("test")) {
    console.error(
      `ERROR: Refusing to run tests against database "${conn.database}".`,
    );
    console.error('The database name must end with "test" (case-insensitive).');
    process.exit(1);
  }

  // 1. Build install scripts from src/.
  console.log("\n=== Building install scripts ===");
  buildAll();

  const resetScript = path.join(root, "scripts", "reset-test-db.sql");
  const testScript = path.join(root, "tests", "run_all.sql");
  
  // 2. For each schema: reset DB, install, test.
  for (const schema of SCHEMAS) {
    const installScript = path.join(root, "dist", `install-${schema}.sql`);

    console.log(`\n=== Resetting test database: ${conn.database} ===`);
    await runSqlcmd(conn, resetScript, { TestDbName: conn.database }, "master");

    console.log(`\n=== Installing schema: ${schema} ===`);
    await runSqlcmd(conn, installScript);

    console.log(`\n=== Testing schema: ${schema} ===`);
    await runSqlcmd(conn, testScript, { SchemaName: schema });
  }

  console.log("\nAll schemas tested.");
}

main().catch((err) => {
  console.error("ERROR:", err.message);
  process.exit(1);
});
