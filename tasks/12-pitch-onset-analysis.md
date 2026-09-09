# 12 — Розпізнавання висоти й атак нот

GitHub: [#12](https://github.com/valtronforever/personal-guitar-coach/issues/12)

Статус: `todo`
Етап: MVP
Залежності: 03, 11

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Отримувати достовірні monophonic note events із чистого гітарного сигналу.

## Робота

- Обрати й обґрунтувати pitch/onset algorithms первинними джерелами та benchmark.
- Аналіз selected mono channel: level/noise evidence, pitch Hz/MIDI/cents, confidence, onset timestamps.
- Відокремити transient/onset від стабільної pitch estimate; repeated same-pitch attacks від sustain.
- Обробити silence, clipping, harmonics, octave ambiguity, out-of-range і негативні polyphonic fixtures.
- Створити deterministic offline runner, annotated corpus/provenance і benchmark report.
- Визначити підтримувану матрицю pitch × note duration × BPM. Заборонити оцінювання за її межами, навіть якщо UI дозволяє показ/прослуховування.

## Критерії приймання

- Досягнуті або обґрунтовано переглянуті з evidence targets у AUDIO-AND-ASSESSMENT.md.
- Detected pitch незалежний від expected exercise note; немає автоматичного виправлення помилок користувача.
- Одна довга нота не стає серією extra notes; повторні атаки однакової ноти розрізняються.
- DSP обмежує queue/memory і не виконується у UI/audio callback.

## Перевірка

Corpus у 44.1/48 kHz, C2–E6, низькі ноти/домінантна друга гармоніка, реальні струни, тиша, шум, clipping, повтори, октави. Записати median/p95 accuracy і latency, не лише один середній показник.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

