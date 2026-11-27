# Compatibility

[Home](../README.md) · [Русский](../README.ru.md#какой-файл-выбрать)

## What the project declares

A build target is not a hardware certification. Source guards, package metadata, compilation, injection and actual runtime behavior are separate checks.

The 1.1.0 source tree defines:

| Variant | Minimum iOS | Architectures | Package architecture | Install layout |
| --- | --- | --- | --- | --- |
| `rootless` | 15.0 | arm64, modern arm64e | `iphoneos-arm64` | Standard `/var/jb` rootless prefix |
| `rootful` | 14.0 | arm64, modern arm64e | `iphoneos-arm` | Rootful prefix |
| `rootful-legacy` | 12.0, below 14.0 | arm64 | `iphoneos-arm` | Rootful prefix |

There is no firmware upper bound in the modern package metadata. **That is not evidence of successful testing on every later iOS release.** iOS 18 falls inside those build ranges but still needs device testing with a compatible jailbreak.

Published releases may predate these targets. Always check the minimum firmware and actual assets of the release you download. Do not relabel an older DEB to pretend it is a newer target.

## Architecture boundaries

Apple changed the arm64e ABI for iOS 14. The current modern toolchain does not produce the old arm64e ABI required by system arm64e processes on iOS 12–13. The legacy package only contains arm64. In particular, do not advertise it as full A12+ system-app support on those systems.

See Theos' [arm64e deployment](https://theos.dev/docs/arm64e-deployment) and [rootless](https://theos.dev/docs/rootless) documentation.

## Jailbreak and loader boundaries

The tweak does not call Dopamine-specific APIs or check a Dopamine version. It relies on standard compatible tweak injection and a substrate-compatible hook interface. This design may be useful across bootstraps, but it does not establish support for every jailbreak by name.

- Rootless and rootful packages are not interchangeable.
- A nonstandard relocated bootstrap may require additional integration and testing.
- Disabling injection for an app also disables SelectBlocks in that app.
- Jailbreak-detection bypasses, hiding injection and defeating an app's security checks are not implemented.
- The tweak cannot provide a jailbreak where none is installed or available.

## App boundaries

- Native path: selected-range setters in `UITextView` and `UITextField`. Some editors do not use them for all user gestures.
- Web path: best-effort long-press detection in a main-document `WKWebView`. Iframes, private browser containers and handle-only selection changes can be missed.
- Secure input is excluded. PDFs, canvas text, games and custom selection engines are not generally supported.
- SpringBoard, Settings and app extensions are excluded by the current process checks.
- The entrance animation needs usable local selection geometry. Otherwise it fades in. The source document is not modified.

## Current verification standard

CI tests the portable game and sound code, web matching, native Foundation normalization and package structure. Package validation checks firmware metadata, expected prefix and binary slices. There is **no maintained device-by-device certification matrix** yet.

When submitting a compatibility result, include the release, exact package variant, iPhone model, iOS, jailbreak/loader and host app version. Please distinguish “installs”, “launches” and “plays correctly”.

## По-русски

Диапазон прошивок в пакете — только один из уровней совместимости. Для запуска нужны правильный ABI процесса, совместимый загрузчик и разрешённая инъекция. Отдельно проверьте, поддерживает ли редактор перехваты выделения. Старый arm64e на iOS 12/13 и 32-битные устройства не включены. Универсальная поддержка всех джейлбрейков не заявляется.
