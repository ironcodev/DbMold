#!/usr/bin/env node

const { installCommand } = require("../lib/installer");

const COMMANDS = {
  install: installCommand,
  help: showHelp,
};

function showHelp() {
  console.log(`Usage: dbmold <command>

Commands:
  install     Install DbMold into a SQL Server database.
  help        Show this help.

Config:
  dbmold looks for dbmold.config.json in the current directory.
  If not found, it will prompt for connection details.

Examples:
  npx dbmold install
  dbmold install
`);
}

async function main() {
  const command = process.argv[2];

  if (!command || !COMMANDS[command]) {
    showHelp();
    process.exit(command ? 1 : 0);
  }

  try {
    await COMMANDS[command]();
  } catch (err) {
    console.error(`\nERROR: ${err.message}`);
    process.exit(1);
  }
}

main();
