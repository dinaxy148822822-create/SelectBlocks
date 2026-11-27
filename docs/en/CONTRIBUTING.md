# Contributing

Thanks for improving SelectBlocks. **English and Russian reports are welcome.** There is no promised response time or guaranteed acceptance of a change.

## Before opening an issue

Search existing issues, check [compatibility](COMPATIBILITY.md) and read the notes for your exact release. Choose the bug or feature template. Reproduce with a harmless sample word and redact personal data.

A useful report distinguishes package installation, selection detection, game launch and actual gameplay. Include the package variant, exact iOS, device, jailbreak/loader and host app version. A claim that a jailbreak is “supported” needs runtime evidence, not only a changed dependency string.

## Development workflow

1. Fork the repository and create a focused branch.
2. Follow the [build guide](BUILDING.md).
3. Keep changes small and explain their behavior and trade-offs.
4. Run relevant portable tests; for UI/injection changes, also report what you could or could not verify on a real device.
5. Update user-facing docs and the changelog when behavior changes.
6. Open a pull request with the supplied template. Do not publish releases or bump versions merely to test a PR.

## Compatibility discipline

Preserve the default rootless build and clean between variants. Keep package metadata, deployment target, actual binary slices and installation prefix consistent. Do not silently broaden firmware requirements, weaken security settings or force injection into excluded/protected processes.

Keep `TriggerWords.h`, `TriggerWords.json` and the web-selection tests in sync. New spellings should be explicit names with positive and negative tests, not unrestricted text commands.

## Style and licensing

Follow `.editorconfig`, preserve existing conventions and avoid unrelated formatting churn. Do not commit DEBs, caches, generated build directories, credentials or private crash reports. Maintain the MIT notice in source distributions. Only submit artwork, sound, text and code you have the right to share under the project's terms.

Security issues are covered in [SECURITY.md](SECURITY.md). Community expectations are in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## По-русски

Перед предложением изменений проверьте текущие ограничения и точную версию пакета. Для ошибок нужны воспроизводимые шаги, версии iOS/джейлбрейка/приложения и обезличенные логи. Проверка сборки не заменяет испытание на устройстве. Пароли, токены, официальные коммерческие ресурсы и чужие личные данные не добавляйте.
