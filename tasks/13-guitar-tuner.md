# 13 — Тюнер поточного строю

GitHub: [#13](https://github.com/valtronforever/personal-guitar-coach/issues/13)

Статус: `pending_user`
Етап: MVP
Залежності: 06, 12

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Допомогти фізично налаштувати всі струни перед практикою.

## Робота

- Auto target і manual string selection для всіх tuning profiles; actual detected note/octave та target frequency.
- Cents indicator, flat/sharp/in-tune labels, confidence і hysteresis/smoothing.
- Початковий in-tune band ±5 cents зі стабільністю не менше 300 ms; уточнити за вимірами.
- Silence/unstable/clipping/out-of-range states; низька confidence не зберігає зелену «налаштовано».
- Спільний AudioCoordinator; вхід у tuner з практики лише після завершення/переривання її attempt.

## Критерії приймання

- Manual string6 у Drop D має target D2; зміна reference A4 змінює reference всіх струн.
- Auto mode не видає октавну гармоніку за правильно налаштовану струну без перевірки.
- Шум/тиша не підтверджують налаштування; feedback зрозумілий без кольору.
- Перехід tuner ↔ practice не створює другого capture pipeline.

## Перевірка

Synthetic detuning ±5/10/25/50 cents, silence after stable tone, near-boundary jitter, octave confusion; фізично налаштувати шість струн у Standard і Drop D, en/uk.

## Докази виконання

Реалізовано `Audio/TunerTracker`, `App/TunerModel`, `TunerView` і Debug-only візуальні fixtures. Auto/manual targets походять з поточного TuningProfile/A4; показуються фактична нота/октава, Hz, cents і signal clarity. Median останніх п’яти cents згладжує лише стрілку; ±5 cents протягом 300 ms за часовою шкалою DSP підтверджує налаштування. Низька якість, пропущена історія та застарілі понад 200 ms snapshots скидають підтвердження. Auto harmonic/unison ambiguity просить manual string; частота не «виправляється» до очікуваної октави.

Спільний coordinator володіє tuner capture; вихід зі сторінки зупиняє тільки свого owner. Незавершений output probe блокує tuner capture. Start/Stop закріплено внизу. 36 нових UI keys мають en/uk; індикація використовує також текст і символи.

Перевірено 2026-09-10: `swift test --package-path Packages/GuitarCoachCore` — 77 тестів/13 suites; `swift test` — 34/9 (зокрема реальний DSP на синтетичній синусоїді → TunerModel → silence). Detuning ±5/10/25/50, raw-boundary jitter, duplicate/gap/intervening clipping, harmonic/manual octave, Drop D та A4=450 покрито тестами. `check_localizations.py` — 279 keys; `check_ui_sources.py` — source type-check. Debug/Release `.app` з ad-hoc signature зібрано. Native UI: Standard string6 target E2, disabled Start без input; English/Ukrainian dark synthetic in-tune/silence, скидання frequency/green. Це не live guitar evidence.

Локальний review: [13-review.md](../docs/reviews/13-review.md). Фізичне налаштування шести струн Standard/Drop D, реальні permission/capture і human accessibility залишено U02/U05/U08 після всіх 22 задач; Xcode UI execution — U07. Issue лишається відкритим до цих перевірок.
