# 07 — Формат уроків і вправ

GitHub: [#7](https://github.com/valtronforever/personal-guitar-coach/issues/7)

Статус: `done`
Етап: MVP
Залежності: 03

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Контент додається як дані, а зв'язки тексту, грифа і табулатури перевіряються автоматично.

## Робота

- Versioned manifests з locale-independent lesson/step/exercise/event IDs; локалізовані текстові ресурси en/uk.
- Step містить fingering або event references/range; exercise — events, tempo range, meter, tuning policy, monophonic/display-only mode.
- Read-only bundle loader та строгий валідатор broken refs, duplicate IDs, positions, timing, localization parity.
- Один повний двомовний sample lesson із нотами, паузою та кількома кроками.
- Описати authoring format із прикладом і правилами оновлення версій у docs/CONTENT-AUTHORING.md.

## Критерії приймання

- Той самий lesson ID доступний у двох мовах із тими самими event refs.
- Невалідний урок відхиляється з конкретною причиною; інші уроки залишаються доступними.
- Читання тексту не потребує audio permission.
- Даних достатньо для переходу step → fretboard + tablature без парсингу prose.

## Перевірка

Valid sample, missing translation, unknown event, bad fret, duplicate ID, negative duration, unsupported mode та round-trip versioned content.

## Докази виконання

- Learning module: catalog/lesson schema v1, en/uk text resources, strict loader, reason codes, stable IDs and visual resolver for event sets/fingerings/text-only steps.
- Урок open-strings-intro: чотири кроки, E2/E4 і паузи, fixed Standard, одна моноголосна вправа. Дані зберігаються в app bundle; читання без audio permission.
- Додано реальний текстовий reader з перемиканням мови без втрати відкритого уроку. Інтерактивна синхронізація й restore selection — задача 10 після 08/09.
- `ValidateLessonContent` перевіряє source та Release bundle: 1 двомовний урок, 0 issues. CI виконує цю перевірку.
- 42 core tests + 7 AppTests: успішно. Bad translation/ref/fret/duration/mode/schema, duplicate IDs, containment, partial recovery та round-trip перевірено.
- Native CUA: усі 4 кроки англійською й українською в тому самому відкритому уроці; 900-point width, унікальні AX heading IDs; аудіовхід не запускався.
- Debug/Release .app, strict codesign, generator/catalog checks (136 ключів): успішно. [Authoring guide](../docs/CONTENT-AUTHORING.md), [self-review](../docs/reviews/07-review.md).
