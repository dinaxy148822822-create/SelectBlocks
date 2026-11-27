# Сборка SelectBlocks

[Главная](../README.md) · [English](en/BUILDING.md) · [Участие в разработке](../CONTRIBUTING.md)

## Инструменты

Нужны настроенный Theos, iOS SDK, подходящий инструментальный набор Apple и `ldid`. Современные arm64e-сборки в CI выполняются на macOS.

Официальные инструкции: [macOS](https://theos.dev/docs/installation-macos), [Linux/Windows через WSL](https://theos.dev/docs/installation-linux), [требования arm64e ABI](https://theos.dev/docs/arm64e-deployment).

На Windows можно использовать GitHub Actions вместо локальной установки. Наличие Linux/WSL не отменяет требований к инструментам для современного arm64e.

## Локальная сборка

```bash
git clone https://github.com/dinaxy148822822-create/SelectBlocks.git
cd SelectBlocks
bash scripts/build.sh rootless
```

Выберите одну цель:

```bash
bash scripts/build.sh rootless       # iOS 15+, arm64 и современный arm64e
bash scripts/build.sh rootful        # iOS 14+, arm64 и современный arm64e
bash scripts/build.sh rootful-legacy # iOS 12–13, только arm64
```

Скрипт копирует соответствующий файл `packaging/*.control` в `control`, очищает результаты и запускает GNU Make. Изменение `control` после локальной сборки ожидаемо; перед коммитом восстановите его, если не планировали менять метаданные. Пакет находится в `packages/`.

Не ограничивайтесь заменой строки архитектуры в старом DEB: пути линковки и срезы библиотеки тоже должны соответствовать варианту.

## Через GitHub Actions

1. Используйте собственный репозиторий или форк, в который у вас есть право записи.
2. Откройте **Actions → Build DEB → Run workflow**. Доступность и стоимость зависят от лимитов GitHub.
3. Сначала выполняются тесты, затем три изолированные сборки.
4. Для каждого DEB проверяются версия, архитектура пакета, срезы библиотеки и путь установки.
5. После успеха всех обязательных заданий публикуется релиз с тремя пакетами.

При ошибке обязательного задания релиз не создаётся. Результаты отдельного успешного задания могут быть доступны в Artifacts. Публикация с уже существующим тегом может завершиться ошибкой: для нового выпуска согласованно обновляйте версию во всех метаданных.

В workflow используется `GITHUB_TOKEN` текущего задания. **Личный токен и пароль Apple ID в исходники добавлять не нужно.** Публикация из форка изменяет релизы форка, не оригинального проекта.

## Тесты

На Linux или macOS:

```bash
cc -std=c11 -O2 -Wall -Wextra tests/test_game.c -o /tmp/selectblocks-game
/tmp/selectblocks-game
cc -std=c11 -O2 -Wall -Wextra tests/test_sound.c -lm -o /tmp/selectblocks-sound
/tmp/selectblocks-sound
node tests/test_selection.js
python3 tests/test_variants.py
```

Нативная проверка Foundation на macOS:

```bash
clang -fobjc-arc -framework Foundation tests/test_triggers.m -o /tmp/selectblocks-triggers
/tmp/selectblocks-triggers
```

Для `tests/validate_package.py` дополнительно нужны `dpkg-deb` и Apple `lipo`. Эти тесты не проверяют касания, реальный вывод звука, анимации и взаимодействие с другими твиками на устройстве.

## Структура исходников

| Файл / папка | Назначение |
| --- | --- |
| `Tweak.xm` | Интерфейс, перехваты выделения, анимация и интеграция |
| `Game.h` | Переносимая логика поля и очков |
| `TriggerWords.h` / `.json` | Нормализация названий, веб-шаблон и список слов |
| `SBAudio.h` / `SoundSynth.h` | Воспроизведение и синтез WAV |
| `packaging/` | Метаданные вариантов DEB |
| `scripts/build.sh` | Сборка с очисткой и выбором варианта |
| `tests/` | Проверки логики, Foundation и пакетов |
| `.github/workflows/build.yml` | Автоматическая сборка и публикация |

Зависимости скачиваются из upstream-репозиториев. Побитовая воспроизводимость и фиксация всех версий зависимостей не заявляются.
