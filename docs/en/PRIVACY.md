# Privacy and local data

[Home](../../README.en.md) · [Security](SECURITY.md)

This document describes the implementation in this repository, not the behavior of iOS, a host app, a jailbreak, a package manager or GitHub.

## Selection handling

- Native code checks the currently selected text only when a supported selection setter runs. Length is capped at 96 UTF-16 code units.
- Matching uses an explicit list of game names and Unicode normalization.
- The WebKit script runs locally in the main document after a supported gesture. It returns a recognized name and its local geometry, or no match. It does not return arbitrary unrecognized selections.
- For the entrance effect, a recognized word is rendered into an in-memory image. The surrounding app is not photographed; the original document is not edited.
- No text-selection log or transmission of selected words is implemented.

## Stored data

Each host app has its own preferences entries:

| Key | Purpose |
| --- | --- |
| `SelectBlocks.state.v1` | Saved game state |
| `SelectBlocks.best.v1` | Highest local score |
| `SelectBlocks.sound.enabled.v1` | Sound-effects preference |

Procedurally generated sound files are cached under the host app's cache directory in `SelectBlocksAudio-v1`. They contain project-generated tones, not microphone audio or selected text. No microphone access is implemented.

There is no shared online account or cross-app save synchronization. Closing or uninstalling the tweak does not promise removal of existing host-app preferences or caches. The host app and iOS may manage or remove those files independently.

## Networking and sound

The tweak does not implement an analytics service, background music stream or network request. Build tooling downloads dependencies, GitHub serves releases, and badges in the README load from GitHub/Shields; these are separate from the installed tweak.

Effects use System Sound Services without reconfiguring the host app's AVAudioSession. Actual playback depends on device settings and platform behavior. The project does not change system volume to force playback.

## Bug reports

Before posting a log or screenshot, remove access tokens, emails, private page text, device identifiers and unrelated app data. Reproduce selection issues using a disposable sample word whenever possible.
