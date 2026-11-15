// lib/prompt.js
const readline = require("readline");

function createInterface() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

function ask(rl, question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => resolve((answer || "").trim()));
  });
}

function askPassword(rl, question) {
  return new Promise((resolve) => {
    process.stdout.write(question);

    if (!process.stdin.isTTY) {
      rl.once("line", (line) => {
        process.stdout.write("\n");
        resolve((line || "").trim());
      });
      return;
    }

    const stdin = process.stdin;
    stdin.setRawMode(true);
    stdin.resume();
    stdin.setEncoding("utf8");

    let password = "";

    const onData = (chunk) => {
      for (const char of chunk) {
        if (char === "\r" || char === "\n") {
          stdin.setRawMode(false);
          stdin.pause();
          stdin.removeListener("data", onData);
          process.stdout.write("\n");
          resolve(password);
          return;
        } else if (char === "\u0003") {
          stdin.setRawMode(false);
          process.stdout.write("\n");
          process.exit(1);
        } else if (char === "\u007f" || char === "\b") {
          if (password.length > 0) {
            password = password.slice(0, -1);
            process.stdout.write("\b \b");
          }
        } else {
          password += char;
          process.stdout.write("*");
        }
      }
    };

    stdin.on("data", onData);
  });
}

async function promptForYesNo(rl, question, defaultValue) {
  const hint = defaultValue ? "[Y/n]" : "[y/N]";
  while (true) {
    const answer = await ask(rl, `${question} ${hint}: `);
    const choice = (answer || "").toLowerCase();

    if (!choice) return defaultValue;
    if (["y", "yes"].includes(choice)) return true;
    if (["n", "no"].includes(choice)) return false;
    console.log('Please answer "y" or "n".');
  }
}

async function promptForSchemas(rl) {
  while (true) {
    const answer = await ask(
      rl,
      'Schema(s) to install — "mold", "m", or "both" [mold]: ',
    );
    const choice = (answer || "mold").toLowerCase();

    if (choice === "mold") return ["mold"];
    if (choice === "m") return ["m"];
    if (["both", "all", "mold,m", "m,mold"].includes(choice))
      return ["mold", "m"];
    console.log('Invalid choice. Please type "mold", "m", or "both".');
  }
}

async function promptForConfig() {
  const rl = createInterface();

  try {
    console.log(
      "\nNo dbmold.config.json found. Please provide connection details.\n",
    );

    const serverInput = await ask(
      rl,
      "Server (e.g., localhost\\SQLEXPRESS) [localhost]: ",
    );
    const server = serverInput || "localhost";

    const database = await ask(rl, "Database: ");
    if (!database) throw new Error("Database is required.");

    const trustedConnection = await promptForYesNo(
      rl,
      "Use Windows Authentication (trusted connection)?",
      false,
    );

    const config = {
      server,
      database,
      trustedConnection,
      trustServerCertificate: true,
      encrypt: false,
    };

    if (!trustedConnection) {
      const user = await ask(rl, "User: ");
      if (!user) throw new Error("User is required for SQL Authentication.");

      const password = await askPassword(rl, "Password: ");
      if (!password) throw new Error("Password is required.");

      config.user = user;
      config.password = password;
    }

    config.schemas = await promptForSchemas(rl);

    // Ask about saving.
    const save = await promptForYesNo(rl, "Save these settings?", true);

    let filename = "dbmold.config.json";
    if (save) {
      const filenameInput = await ask(rl, `Config filename [${filename}]: `);
      filename = filenameInput || filename;
    }

    return { config, save, filename };
  } finally {
    rl.close();
  }
}

module.exports = { promptForConfig };
