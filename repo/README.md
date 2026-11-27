# Direct source / Прямой источник

Чтобы исключить зависимость APT от маршрутов GitHub Pages, добавлено зеркало в отдельной ветке `apt`.

Rootless:
`https://raw.githubusercontent.com/dinaxy148822822-create/selectblocks/apt/`

Rootful: тот же адрес с `rootful/` в конце. Legacy: с `legacy/`.

Адрес заработает после успешного шага **Publish direct APT mirror and verify live package bytes**. Файл `repository-health.md` в ветке `apt` содержит реальные результаты проверки HTTP и SHA256 для индексов и DEB. Проверяется также User-Agent Sileo. Зелёная сборка без этих проверок не считается подтверждением доступности пакетов.

English: the dedicated `apt` branch provides a direct source independent of GitHub Pages routing. The URL becomes available after the live verification step succeeds. See `repository-health.md` on that branch for actual HTTP and SHA256 checks. Metadata remains unsigned; never disable APT security checks globally.

---

# Sileo / Zebra APT source · APT-источник

## Русский

### Одноразовое включение владельцем

1. Откройте [Settings → Pages](https://github.com/dinaxy148822822-create/SelectBlocks/settings/pages).
2. В **Build and deployment → Source** выберите **GitHub Actions**.
3. Откройте **Actions → Publish APT Repository → Run workflow**.
4. Дождитесь успешного задания **deploy**. До этого URL может возвращать 404.

После публикации пользователям доступны:

| Вариант | Адрес источника |
| --- | --- |
| Rootless | `https://dinaxy148822822-create.github.io/SelectBlocks/` |
| Rootful | `https://dinaxy148822822-create.github.io/SelectBlocks/rootful/` |
| Legacy rootful arm64 | `https://dinaxy148822822-create.github.io/SelectBlocks/legacy/` |

Откройте страницу на iPhone, выберите свой вариант и нажмите Sileo или Zebra. Либо вручную добавьте соответствующий адрес в «Источники». Не добавляйте все варианты одновременно. Сам адрес github.com — это исходники, а не APT-источник.

Источник содержит только реальные DEB последнего обычного релиза. При новом релизе или успешном Build DEB он обновляется автоматически; предусмотрены ручной и ежедневный запуск. Требования iOS берутся из пакета. Rootless и rootful не взаимозаменяемы.

**Безопасность:** индексы содержат SHA-256/SHA-512 и размещаются по HTTPS, но пока не подписаны GPG. Это не замена криптографической подписи. Не отключайте проверки APT глобально. Если политика вашего клиента требует подпись, этот источник пока не подходит.

## English

### One-time owner setup

1. Open [Settings → Pages](https://github.com/dinaxy148822822-create/SelectBlocks/settings/pages).
2. Set **Build and deployment → Source → GitHub Actions**.
3. Open **Actions → Publish APT Repository → Run workflow**.
4. Wait for a successful **deploy** job. The URL can return 404 until then.

The table above lists the independent rootless, rootful and legacy sources. Open the page on your iPhone, choose the matching variant and tap Sileo or Zebra, or paste its URL into Sources. Do not add all variants simultaneously.

Only actual DEBs from the latest stable GitHub release are indexed. Publication runs after a new release or a successful Build DEB workflow, with manual and daily refresh options. Firmware requirements come from the package itself.

**Security:** indexes provide SHA-256/SHA-512 hashes over HTTPS, but are not GPG-signed yet. Never disable APT security checks globally. Clients whose policy requires signatures cannot use this unsigned source as-is.

## Technical layout

Each channel has `Release`, `Packages`, `Packages.gz`, `Packages.bz2`, a local `pool/`, an icon and a bilingual landing page. The build validates DEB metadata, contents, asset size and GitHub SHA-256 digest when present. Old incompatible architectures are not mixed into one index. Failed validation prevents deployment.

The workflow cannot enable Pages using its ordinary GITHUB_TOKEN. Until an owner enables it, the validated site is uploaded as a Pages artifact and deployment is skipped with setup instructions.
