# SelectBlocks 1.2.0 · Цветные буквы при появлении

Во время начальной анимации каждая буква выбранного слова отдельно переливается цветами фигур: голубой, жёлтый, фиолетовый, зелёный, красный, синий и оранжевый. Эффект применяется к летящему слову и заголовку при его появлении, а не окрашивает всё слово одним цветом. После вступления возвращается обычный заголовок, игра не меняется.

- Плавная смена цветов без стробирования прозрачности и без постоянного мигания во время игры.
- Уважает системное «Уменьшение движения»: цветовая анимация отключается.
- Разбиение по составным Unicode-символам, включая русский и другие поддерживаемые языки.
- Используется существующий таймер; отдельного бесконечного цикла нет. Эффект очищается при завершении вступления, закрытии и уходе в фон.
- Звуки, управление, очки, сохранения и диапазоны совместимости не менялись.

Три варианта: rootless iOS 15+, rootful iOS 14+, rootful legacy iOS 12–13 (arm64). Проверка сборки не заменяет визуальную проверку на устройстве.

## English

Per-letter tetromino-color shimmer during the opening word flight and title reveal. Individual Unicode graphemes receive different palette offsets; the whole word is not flashed as one color. Smooth color blending, no opacity strobe, no animation during gameplay, reduced-motion opt-out and close/background cleanup. Uses the existing timer. Gameplay, audio, saves and compatibility variants are unchanged. Native device visual confirmation is still required.
