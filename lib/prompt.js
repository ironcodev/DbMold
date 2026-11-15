const readline = require("readline");

function createInterface() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

/**
 * Ask a single question. Returns the trimmed answer.
 */
function ask(rl, question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => resolve((answer || "").trim()));
  });
}

/**
 * Ask for a password, masking input with asterisks.
 * Falls back to plain input if not running in a TTY.
 */
function askPassword(rl, question) {
  return new Promise((resolve) => {
    process.stdout.write(question);

    if (!process.stdin.isTTY) {
      // Non-interactive (e.g., piped input): read a line normally.
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
          // Ctrl+C
          stdin.setRawMode(false);
          process.stdout.write("\n");
          process.exit(1);
        } else if (char === "\u007f" || char === "\b") {
          // Backspace
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

async function promptForConfig() {
  const rl = createInterface();

  try {
    console.log("\nNo dbmold.config.json found. Please provide connection details.\n");

    const serverInput = await ask(rl, "Server (e.g., localhost\\SQLEXPRESS) [localhost]: ");
    const server = serverInput || "localhost";

    const database = await ask(rl, "Database: ");
    if (!database) throw new Error("Database is required.");

    const user = await ask(rl, "User: ");
    if (!user) throw new Error("User is required (SQL Authentication).");

    const password = await askPassword(rl, "Password: ");
    if (!password) throw new Error("Password is required.");

    const schemas = await promptForSchemas(rl);

    return {
      server,
      database,
      user,
      password,
      schemas,
      options: {
        encrypt: false,
        trustServerCertificate: true,
      },
    };
  } finally {
    rl.close();
  }
}

/**
 * Ask which schemas to install.
 * Returns an array of schema names (e.g., ['mold'] or ['mold', 'm']).
 */
async function promptForSchemas(rl) {
  while (true) {
    const answer = await ask(rl, 'Schema(s) to install — "mold", "m", or "both" [mold]: ');

    const choice = (answer || "mold").toLowerCase();

    if (choice === "mold") return ["mold"];
    if (choice === "m") return ["m"];
    if (choice === "both" || choice === "all" || choice === "mold,m" || choice === "m,mold") {
      return ["mold", "m"];
    }

    console.log('Invalid choice. Please type "mold", "m", or "both".');
  }
}

module.exports = { promptForConfig };

module.exports = { promptForConfig };
