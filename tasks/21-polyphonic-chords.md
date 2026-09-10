# 21 — Дослідження оцінювання акордів

GitHub: [#21](https://github.com/valtronforever/personal-guitar-coach/issues/21)

Статус: `pending_user`
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

Дослідження реалізовано: [звіт](../docs/research/21-chords.md), [ADR 006 / no-go](../docs/decisions/006-polyphonic-feasibility.md), [відтворення й corpus](../Research/Chords/README.md), [локальний review](../docs/reviews/21-review.md), [подальший backlog](follow-up/chord-assessment.md).

- 12 реальних акустичних pickup-записів GuitarSet, 6 виконавців, 296.196 s; player-held-out split, чистий і явно штучно перевантажений сигнал. Закріплено revision, hashes, ліцензію й обмеження анотацій.
- Chroma, harmonic NNLS та реальний production monophonic baseline перевірено окремими offline CLI; 74 синтетичні controls і 5 contract tests.
- Held-out polyphonic exact-set accuracy 22.4% / 20.4%; identity/unknown/coverage та strum precision/recall не проходять frozen gates. Рішення: не додавати chord hints або score до UI. No-go не означає неможливість майбутнього розпізнавання.
- `pending_user`: U06 — незалежні анотації та справжні clean/distorted electric DI/мікрофон/п'єзо записи; native streaming latency/CPU не виміряні. Усі software результати відтворювані; ці фізичні gates перенесено на фінальний крок за вказівкою користувача.
