# Installation and recovery

[Home](../../README.en.md) · [Русская инструкция](../../README.md#установка) · [Compatibility](COMPATIBILITY.md)

## Before you begin

- Use a jailbroken device with a supported 64-bit process architecture.
- Check the release's own minimum iOS and package layout, not only the `main` branch documentation.
- Know how your jailbreak starts **without tweak injection** and how to remove a package in that state. Keep important data backed up.
- Do not install the rootful package into a rootless bootstrap or vice versa. Do not force an incompatible architecture or firmware dependency.

## Install a release asset

1. Open [Releases](https://github.com/dinaxy148822822-create/SelectBlocks/releases).
2. Read the notes and expand **Assets**.
3. Download the matching `.deb`. GitHub's automatically generated **Source code** archives are not installable packages.
4. Open the package with a compatible package manager or Filza and install it. Follow any restart prompt.
5. Fully quit and reopen the target app so its process can load the updated library.
6. Make sure tweak injection is allowed for the app. Select an entire [recognized name](../../TriggerWords.json) in a supported text view and wait briefly.

The project currently distributes direct DEB downloads through GitHub Releases. **A Sileo/APT repository URL is not provided.** Adding this GitHub repository URL as a package source will not install the tweak.

## Update

Choose the same compatible package layout and a newer version. Game state uses the existing per-app preferences format; keep a copy of the last working DEB for rollback. A release's notes may override these general instructions.

## Remove or recover

If only one app crashes, disable tweak injection for that app using tools supported by your jailbreak, then remove SelectBlocks. If needed, start the jailbreak without tweak injection and uninstall it through the package manager. Exact steps vary by jailbreak and version.

After removal, restart affected apps. Game state, the record and sound preference may remain in the app's preferences; generated sound files can remain in its cache. The package does not erase the host app's data.

## First launch checklist

- Is the release compatible with this firmware and architecture?
- Is the package rootless or rootful as required?
- Is injection enabled for the app?
- Is the text in a standard editor, or the main document of a WKWebView?
- Is the selected text an exact recognized name rather than a phrase?

Still stuck? See the [FAQ](FAQ.md) or [open a bug report](https://github.com/dinaxy148822822-create/SelectBlocks/issues/new/choose). Remove personal information from logs and screenshots.
