# 17 — Оцінювання висоти та ритму

GitHub: [#17](https://github.com/valtronforever/personal-guitar-coach/issues/17)

Статус: `pending_user`
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

Реалізовано `AssessmentEngine` у Learning та валідовані `AssessedPractice`/`AssessmentParameters` у Domain. Монотонне DP зіставляє час і порядок один-до-одного; pitch не впливає на вибір відповідності. Radius ≤300 ms та ≤49% найближчого attack interval; rhythm tolerance ≤100 ms та ≤45% найкоротшого interval. Висота рахується щодо target frequency зі snapshot A4. Missed/uncertain залишаються у знаменнику; extras, у тому числі на паузах, знижують оцінку. Деталі — [ADR 004](../docs/decisions/004-assessment.md).

Ненадійна calibration/clock evidence вимикає rhythm/overall. Failed input, partial і >20% uncertain expected/extra observations не мають aggregate grades. Non-silent uncertainty spans відрізняються від здорової тиші; clipping не зникає через чистий останній frame. Model підтверджує completed healthy silence як пропуски, не приховану проблему входу.

`AssessmentStore` оцінює поза MainActor й чекає атомарного save перед повтором. Помилка залишає bounded pending attempt, вимикає repeat і дає retry без дублювання. Session schema 2 містить повну evidence/параметри/результат; schema 1 читається без regrade. Зберігаються lesson/exercise/tuning/capability/analysis/scoring/calibration versions. Historical capability не блокує читання; новий start перевіряє актуальні межі. У Practice є двомовний стислий результат; розгорнуті поради й прогрес — задача 18.

Знайдено transient octave у публічному 44.1-kHz записі: event pitch `mono-mpm-flux-2` використовує медіану п’яти підтверджених post-onset frames. Onset і 300-ms timeout збережено. Експериментальна energy-rise умова для onset була відхилена після регресії коротких повторів; фінальний onset detector лишився попереднім.

Перевірки: 119 reported core tests (1 opt-in hardware skip), 47 App tests; 9 golden/boundary assessment tests включають perfect=100, ±50 ms, semitone/octave pitch=0, early/late, dropped/extra/rest, uncertain/clipped/noisy/missing/partial, короткі interval, NaN та 1024×2048 bound. Fake practice → evaluator → repository перевірено на двох окремих повторах. Mixed legacy/current history, corrupt/future preservation, exact retry та capability restore перевірено тестами.

Повний DSP benchmark — 3360 випадків, усі musical/quality gates проходять. Recorded pipeline правильно зіставляє перші атаки всіх 32 файлів із onset annotation; 18 graded, 14 unscored через uncertain extras. 2 B3 файли без onset annotation лишаються тільки у pitch benchmark. Це public acoustic development corpus із синтетичним padding/clock; secondary release/boundary transients не мають повної людської розмітки. [Звіт і per-clip evidence](../docs/benchmarks/17-assessment.md), [повний compact artifact](../docs/benchmarks/17-audio-analysis.json).

421 en/uk ключ, generated-project check, UI-source type-check, локальні Debug/Release .app з ad-hoc підписом проходять. [Локальний review](../docs/reviews/17-review.md) виконав той самий агент. Нативна перевірка нової result card лишилась відкритою через втрату CUA native-pipe connection; фактичний Xcode UI suite — U07. Реальна електрогітара/інтерфейс, held-out corpus, ручна музична оцінка й calibrated timing — U02/U03/U08/U10 після всіх 22 програмних задач. Issue лишається відкритим.
