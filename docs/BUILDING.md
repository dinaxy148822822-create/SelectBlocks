# Build SelectBlocks

[Home](../README.md) · [Contributing](../CONTRIBUTING.md)

## Tooling

Use a configured Theos environment with an iOS SDK, matching Apple toolchain and `ldid`. The modern arm64e CI targets use macOS. The official setup instructions are the source of truth:

- [macOS](https://theos.dev/docs/installation-macos)
- [Linux / Windows with WSL](https://theos.dev/docs/installation-linux)
- [arm64e ABI requirements](https://theos.dev/docs/arm64e-deployment)

Windows users can use the repository's **Actions** workflow instead of installing a full local toolchain. A Linux/WSL toolchain must independently support the requested architecture; do not assume the modern arm64e requirements disappear outside macOS.

## Local package

```bash
git clone https://github.com/dinaxy148822822-create/SelectBlocks.git
cd SelectBlocks
bash scripts/build.sh rootless
```

Choose exactly one build variant:

```bash
bash scripts/build.sh rootless       # iOS 15+, arm64 + modern arm64e
bash scripts/build.sh rootful        # iOS 14+, arm64 + modern arm64e
bash scripts/build.sh rootful-legacy # iOS 12–13, arm64 only
```

The script selects the correct `packaging/*.control` file, copies it to `control`, runs `clean` and invokes GNU Make. The modified `control` is an expected local build side effect; restore it before committing unless intentionally updating metadata. Build outputs are in `packages/`.

The source default is rootless. Avoid changing only the package architecture string or moving files inside an already-built DEB; the binary's link paths and slices must also match the variant.

## GitHub Actions

1. Fork or use a repository you are authorized to write to.
2. Open **Actions → Build DEB → Run workflow**. Availability and billing depend on your GitHub plan and settings.
3. The test job runs before the build matrix.
4. Three isolated builds produce rootless, rootful and legacy artifacts.
5. Each DEB is checked for version, package architecture, library slices and installation prefix.
6. Only after all required jobs succeed does the release job attach all three packages to the new version tag.

A release is **not** created if a required job fails. Artifacts from an individual successful build may still be available. A repeated release using an existing tag can fail; bump the version consistently in all metadata before preparing a new release. Publishing in a fork changes that fork's releases, not this repository.

No personal token is required inside the repository workflow: it uses the job-scoped `GITHUB_TOKEN`. Never commit tokens or Apple account credentials.

## Tests

Portable tests on Linux or macOS:

```bash
cc -std=c11 -O2 -Wall -Wextra tests/test_game.c -o /tmp/selectblocks-game
/tmp/selectblocks-game
cc -std=c11 -O2 -Wall -Wextra tests/test_sound.c -lm -o /tmp/selectblocks-sound
/tmp/selectblocks-sound
node tests/test_selection.js
python3 tests/test_variants.py
```

Native Foundation normalization test on macOS:

```bash
clang -fobjc-arc -framework Foundation tests/test_triggers.m -o /tmp/selectblocks-triggers
/tmp/selectblocks-triggers
```

`tests/validate_package.py` additionally needs `dpkg-deb` and Apple's `lipo`. Source-level and package tests do not test touch behavior, audio output, animations or compatibility with other injected tweaks on a real device.

## Source map

| File / folder | Responsibility |
| --- | --- |
| `Tweak.xm` | Native UI, selection hooks, animation and game integration |
| `Game.h` | Portable board and scoring logic |
| `TriggerWords.h` / `.json` | Trigger normalization, web template and documented names |
| `SBAudio.h` / `SoundSynth.h` | Playback adapter and procedural WAV synthesis |
| `packaging/` | Variant-specific Debian metadata |
| `scripts/build.sh` | Clean variant-aware local build |
| `tests/` | Portable, Foundation and package checks |
| `.github/workflows/build.yml` | CI and release publication |

The workflow currently downloads its toolchain and SDK dependencies from their upstream repositories. Builds are not claimed to be bit-for-bit reproducible or dependency-pinned.
