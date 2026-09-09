# 07 — Формат уроків і вправ

GitHub: [#7](https://github.com/valtronforever/personal-guitar-coach/issues/7)

Статус: `todo`
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

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

