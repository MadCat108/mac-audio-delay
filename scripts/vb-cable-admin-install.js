function shellQuote(value) {
  return "'" + value.replace(/'/g, "'\\''") + "'";
}

function run(argv) {
  if (argv.length !== 1) {
    throw new Error("Expected the installer package path.");
  }

  const app = Application.currentApplication();
  app.includeStandardAdditions = true;

  const command = "/usr/sbin/installer -pkg " + shellQuote(argv[0]) + " -target /";
  return app.doShellScript(command, { administratorPrivileges: true });
}
