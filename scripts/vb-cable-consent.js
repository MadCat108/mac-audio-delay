function run() {
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;

  const notice = [
    "Audio Delay requires the standard VB-CABLE audio driver from VB-Audio Software.",
    "",
    "VB-CABLE is donationware. All contributions are welcome. If you find it useful, or use it professionally, please purchase an appropriate license from VB-Audio.",
    "",
    "Origin and licensing:",
    "https://vb-cable.com",
    "https://vb-audio.com/Services/licensing.htm",
    "",
    "The unchanged official, Apple-notarized package will be installed. Continuing means that you accept VB-Audio's license terms."
  ].join("\n");

  app.displayDialog(notice, {
    withTitle: "Install VB-CABLE",
    buttons: ["Cancel", "Agree and Install"],
    defaultButton: "Agree and Install",
    cancelButton: "Cancel"
  });

  return "agreed";
}
