# 17 — Оцінювання висоти та ритму

GitHub: [#17](https://github.com/valtronforever/personal-guitar-coach/issues/17)

Статус: `todo`
Етап: MVP
Залежності: 03, 12, 15, 16

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Отримати пояснювану, відтворювану оцінку кожної спроби.

## Робота

- Реалізувати monotonic one-to-one event alignment з insertions/deletions; визначити bounded match window.
- Per-event pitch/timing, missed/extra/uncertain, pause violations; cents щодо target frequency.
- Реалізувати validity gates і початкову формулу з AUDIO-AND-ASSESSMENT.md.
- Валідувати thresholds на annotated corpus, version parameter set; зберігати score inputs і snapshots.
- Pitch-only режим без overall за ненадійної rhythm calibration.
- Розрізняти healthy all-missed attempt і невстановлений/перерваний вхід.

## Критерії приймання

- Perfect fixture =100; healthy silence після preflight =0; missing/failed input =unscored.
- Half-step/octave error має pitch score 0; одна атака не зараховується двічі.
- Extra notes й ноти в pauses знижують результат; uncertain не вилучаються приховано зі знаменника.
- Known compensated latency не штрафує ритм; пауза або partial attempt не породжує overall.
- Результат обмежений 0…100, deterministic і захищений від N=0/NaN.

## Перевірка

Golden fixtures: perfect, wrong pitch, early/late, dropped middle note, repeated same pitch, extra, rests, low-confidence, capture gaps, short intervals і shifted sequence. Перевірити alignment вручну на реальних annotated записах та записати evidence.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
