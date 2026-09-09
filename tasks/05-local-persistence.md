# 05 — Локальні налаштування та історія

GitHub: [#5](https://github.com/valtronforever/personal-guitar-coach/issues/5)

Статус: `todo`
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

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
