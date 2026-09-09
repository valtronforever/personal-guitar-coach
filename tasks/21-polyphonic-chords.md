# 21 — Дослідження оцінювання акордів

GitHub: [#21](https://github.com/valtronforever/personal-guitar-coach/issues/21)

Статус: `todo`
Етап: Після MVP
Залежності: 20

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Визначити, чи можна достовірно оцінювати одночасні ноти акорду в умовах цього продукту.

## Робота

- Описати окремо chord identity, missing/extra notes і strumming rhythm; не змішувати ці завдання.
- Зібрати annotated clean/distorted chord corpus із різними voicings; перевірити алгоритми та можливі локальні ML-моделі.
- Виміряти precision/recall, confusion, latency/CPU та unknown handling на unseen recordings.
- Визначити, чи результат дозволяє оцінку акорду, лише підказку або відмову через ambiguity.
- Написати ADR із go/no-go, ліцензіями, підтримуваними акордами й окремим подальшим implementation backlog.

## Критерії приймання

- Дослідницький звіт містить corpus, метод, held-out результати й відтворюваний benchmark.
- Немає висновків про струни/пальці, яких не підтверджує аудіо.
- UI MVP не перемикається на неперевірений поліфонічний score.
- No-go є допустимим результатом дослідження; задача не обіцяє впровадження наперед.

## Перевірка

Negative/ambiguous examples, різні voicings, unseen guitar recordings і порівняння з monophonic baseline.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
