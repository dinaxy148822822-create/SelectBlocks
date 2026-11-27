# FAQ and troubleshooting

[Home](../../README.en.md) · [Install](INSTALL.md) · [Compatibility](COMPATIBILITY.md)

## Is this an App Store application?

No. It is a jailbreak tweak loaded into compatible app processes. It cannot run without an appropriate loader and enabled injection.

## Can I add the GitHub URL to Sileo as a source?

No APT repository is provided here. Download the `.deb` from a release's **Assets** and install it with a compatible package manager.

## Nothing happens when I select the word

Check the exact spelling in `TriggerWords.json`, injection settings and the app's editor type. Try a standard non-secure text field. A PDF, canvas, iframe or custom editor may not be supported. A browser's text selection is not guaranteed just because it visually resembles a standard field.

## Does it work with my jailbreak or iOS 18?

The modern source targets include iOS 18, but successful use on your exact setup is not certified. Choose the correct package layout, architecture and release. There is no Dopamine-version-specific API dependency. See [compatibility](COMPATIBILITY.md).

## Why is an older release more restrictive than the README?

The README follows the current source branch. Older compiled DEBs retain their original firmware constraints and architectures. Read the notes attached to the release; do not rename or force-install the old package.

## The game opens but the word does not fly upward

The effect needs a usable selection rectangle. If that geometry is missing, a simple fade is expected. Reduced Motion also disables the flight. Web page scaling and custom fonts can make the best-effort copy differ from the source text.

## Why are scores and sound settings different in two apps?

State is saved independently in each host app. Cross-app synchronization is not implemented.

## Why is a restored game paused?

Restoring a saved live game starts paused. Press **PLAY** to continue.

## No sound, or sound is too quiet

Check **SND / OFF**, the device's silent setting and volume. The effects are short, restrained UI-style tones. No background music is included. The tweak does not force a new audio session or change the system volume; some environments can suppress effects.

## The app crashes or stops opening

Disable injection for it, or use your jailbreak's supported no-injection startup and remove SelectBlocks. Restart the affected app. Keep a previous working release for rollback. Include the release, package variant, firmware, loader and host app version in a bug report; redact private data from logs.

## Why does the build fail?

Open the first failed CI step rather than only the final summary. Toolchain, network, SDK availability, package metadata, branch permissions and an already-existing release tag can all prevent publication. A green portable test is not the same as a successful DEB build.

## Is this official Tetris?

No. It is an independent falling-block implementation with original procedural graphics and sound effects. Commercial recordings, music and artwork are not included. Rotation and scoring do not implement every modern official game rule.

## Можно писать об ошибках по-русски?

Да. Заполните [шаблон](https://github.com/dinaxy148822822-create/SelectBlocks/issues/new/choose), укажите версии и шаги воспроизведения. Никогда не прикладывайте токены и личные данные.
