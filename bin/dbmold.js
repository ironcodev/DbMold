#!/usr/bin/env node

const pkg = require("../package.json");
const { installCommand } = require("../lib/installer");
const { connectCommand } = require("../lib/connector");

const HELP_TEXT = `
Usage: dbmold <command> [options]

Commands:
  install     Install DbMold schemas into a SQL Server database.
  connect     Test the connection to a SQL Server database.
  help        Show this help.

Options:
  -c, --config <path>   Use the specified config file (default: dbmold.config.json).
  -e, --env <name>      Merge dbmold.config.<name>.json over the base config.
                        Defaults to the DBMOLD_ENV environment variable, if set.
  -v, --version         Print the version number and exit.
  -?, /?                Show this help and exit.

Config:
  DbMold looks for dbmold.config.json in the current directory.
  If not found, it prompts for connection details.

Examples:
  npx dbmold install
  npx dbmold install --env prod
  npx dbmold connect -c myconfig.json -e dev
  dbmold -v
`;

function showHelp() {
  console.log(HELP_TEXT.trim());
}

function showVersion() {
  console.log(pkg.version);
}

function parseArgs(argv) {
  const result = {
    command: null,
    configPath: null,
    env: null,
    error: null,
  };
  let i = 0;

  while (i < argv.length) {
    const arg = argv[i];

    if (arg === "-v" || arg === "--version") {
      result.command = "version";
      return result;
    }
    if (arg === "-?" || arg === "/?" || arg === "-h" || arg === "--help") {
      result.command = "help";
      return result;
    }

    if (arg === "-c" || arg === "--config") {
      const value = argv[i + 1];
      if (!value || value.startsWith("-")) {
        result.error = `Missing value for ${arg}.`;
        return result;
      }
      result.configPath = value;
      i += 2;
      continue;
    }
    if (arg.startsWith("--config=")) {
      const value = arg.slice("--config=".length);
      if (!value) {
        result.error = "Missing value for --config.";
        return result;
      }
      result.configPath = value;
      i += 1;
      continue;
    }

    if (arg === "-e" || arg === "--env") {
      const value = argv[i + 1];
      if (!value || value.startsWith("-")) {
        result.error = `Missing value for ${arg}.`;
        return result;
      }
      result.env = value;
      i += 2;
      continue;
    }
    if (arg.startsWith("--env=")) {
      const value = arg.slice("--env=".length);
      if (!value) {
        result.error = "Missing value for --env.";
        return result;
      }
      result.env = value;
      i += 1;
      continue;
    }

    if (!result.command && !arg.startsWith("-")) {
      result.command = arg;
      i += 1;
      continue;
    }

    result.error = `Unknown argument: ${arg}`;
    return result;
  }

  // Env fallback: DBMOLD_ENV.
  if (!result.env && process.env.DBMOLD_ENV) {
    result.env = process.env.DBMOLD_ENV;
  }

  return result;
}

async function main() {
  const parsed = parseArgs(process.argv.slice(2));

  if (parsed.error) {
    console.error(`ERROR: ${parsed.error}\n`);
    showHelp();
    process.exit(1);
  }

  switch (parsed.command) {
    case "version":
      showVersion();
      return;
    case "help":
    case null:
      showHelp();
      return;
    case "install":
      await installCommand({ configPath: parsed.configPath, env: parsed.env });
      return;
    case "connect":
      await connectCommand({ configPath: parsed.configPath, env: parsed.env });
      return;
    default:
      console.error(`Unknown command: ${parsed.command}\n`);
      showHelp();
      process.exit(1);
  }
}

main().catch((err) => {
  console.error(`\nERROR: ${err.message}`);
  process.exit(1);
});
