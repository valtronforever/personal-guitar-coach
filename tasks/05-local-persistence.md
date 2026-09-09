# 05 — Локальні налаштування та історія

GitHub: [#5](https://github.com/valtronforever/personal-guitar-coach/issues/5)

Статус: `done`
Етап: MVP
Залежності: 03, 04

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Зберігати налаштування і спроби на Mac без сервера.

## Робота

- Repository contracts і Codable versioned envelopes для tuning profiles, session snapshots, assessment results.
- UserDefaults для простих UI preferences; Application Support для domain documents.
- Атомарний запис, session files + відновлюваний індекс, migration entry point, recovery для пошкоджених/невідомих версій.
- Locale-neutral IDs, snapshots версій контенту/строю/калібрування. Дані старих спроб не змінювати при редагуванні налаштувань.
- Команда очищення історії з конкретним попередженням про видалення; не зберігати raw audio за замовчуванням.

## Критерії приймання

- Після перезапуску повертаються мова, профіль інструмента та збережені результати.
- Один пошкоджений session file не знищує інші; користувач бачить зрозуміле повідомлення.
- Перейменування профілю та зміна поточного BPM не змінюють минулу спробу.
- Запис помилки диска не відображається як успішне збереження.

## Перевірка

Round-trip snapshots, atomic-write failure, corrupt file, unsupported schema, migration fixture, rebuild index і delete flow. Налаштування тестів ізольовані від реальних даних користувача.

## Докази виконання

- Persistence module: repository protocols, actor, atomic JSON writes, preferences v2, immutable attempts v1, result envelopes v1, rebuildable index, explicit recovery with original-file copy.
- Snapshot містить повну вправу, профіль інструмента, BPM/range, час і калібрування з revision та algorithm version. Майбутні/пошкоджені дані не перезаписуються під час читання.
- UI: збереження джерела сигналу, чесні помилки, відновлення preferences, читання реальної історії, очищення з точним попередженням. Немає збереження raw audio.
- `swift test --package-path Packages/GuitarCoachCore`: 29 тестів; root `swift test`: 3 тести UI-state. Використано Xcode DEVELOPER_DIR; тестові дані лише в temporary directories.
- Debug/Release .app, strict codesign, generator check та 89 en/uk localization keys: успішно. CI виконує обидві test suites.
- Native CUA: джерело Pickup збереглося після relaunch; повернуто Electric interface. Порожня історія без фальшивих результатів; Clear disabled.
- [Self-review](../docs/reviews/05-review.md). Xcode UI-test execution лишається у U07; повні result details — задача 18.
