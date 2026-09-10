# 16 — Повний цикл практики

GitHub: [#16](https://github.com/valtronforever/personal-guitar-coach/issues/16)

Статус: `pending_user`
Етап: MVP
Залежності: 06, 10, 13, 14, 15

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

З'єднати вправу, сигнал, метроном і UI в керований цикл гри.

## Робота

- State machine із AUDIO-AND-ASSESSMENT.md; immutable snapshots exercise/tuning/audio/tempo/calibration.
- Preflight signal test, tuning mismatch, supported DSP range/tempo, count-in, running і finalization.
- Вибір фрагмента цілими тактами, repeat loops як окремі attempts, retry.
- Live expected/observed feedback без передчасної остаточної оцінки; finite analysis buffers.
- Pause/seek/tempo changes закривають partial attempt; resume = новий відлік і attempt.
- Hot-unplug, sleep, permission/format change зупиняють оцінювання з правильною причиною.

## Критерії приймання

- Урок відкриває саме свою вправу; курсор і очікувані ноти узгоджені зі звуком.
- Count-in не додає missed/extra events; фіналізація дочікується останньої аналізованої ноти.
- Переривання не виглядає як completed success або оцінка 0.
- Restart не зберігає попередні attack events; tuning snapshot не змінюється під час running.

## Перевірка

State transition tests із fake clock/device/observations; complete, cancel, pause/resume, empty signal, loop boundary, unplug і last-note tail. Повний hardware run до фіналізації evidence, до scoring інтеграції.

## Докази виконання

Реалізовано `PracticeConfiguration`, `PracticeStateMachine`, валідовану immutable `PracticeEvidence`, bounded collector та спільний `PracticeModel`. Вправа переходить із уроку зі своїм ID/version; зберігаються стрій, джерело, маршрут, калібрування, темп і фрагмент. Preflight потребує явного підтвердження фізичного строю та свіжого стабільного сигналу ≥200 ms; за 10 s без нього завершується помилкою входу. Після успішного preflight справний порожній запис залишається завершеною evidence для пропусків у задачі 17.

Курсор і count-in читають audio transport. Pause, seek навіть у той самий такт, зміна темпу/строю/вправи закривають partial; retry має новий UUID і відлік. Repeat зберігає capture, але фіналізує кожну спробу окремо й починає новий count-in після дренування входу: без обіцянки безшовного циклу. Collector зберігає максимум 2048 незалежних атак, 4096 clipped intervals; пропущена історія або переповнення переривають спробу. Дані handed off через async callback із backpressure для оцінювання/збереження у задачі 17; фіктивні оцінки не створюються.

Guard становить 100 ms до/після оцінюваного фрагмента. Фіналізація чекає 1.4 s + відому input hardware latency після output completion та analyzer watermark за завершальним guard + 300 ms. Сигнал count-in поза початковим guard не потрапляє в evidence. Clock drift прив'язаний до початкового analyzer capture origin, тому новий цикл не приховує накопичений drift.

Перевірки: `swift test --package-path Packages/GuitarCoachCore` — 107 reported tests (1 opt-in hardware test skipped); `swift test` — 44 App tests. Покрито переходи, snapshot invariants, межі пам'яті, пізню останню атаку, clipping span updates, незворотну втрату історії, repeat/healthy silence, missing signal, pause/retry, tempo/seek, navigation і unplug у final drain. Fake runtime і synthetic analyzer відокремлено від hardware evidence.

`check_localizations.py` — 396 en/uk ключів; `generate_project.py --check` і `check_ui_sources.py` проходять. Нативний UI перевірено read-only у English/dark та Українська/light, включно з мінімальним 900×620 content size, згортанням параметрів, усіма шістьма струнами грифа/TAB і недоступним Start без маршруту. Xcode UI-test source перевіряє окремі accessibility IDs і disabled controls; фактичний запуск suite потребує U07. Локальний review: [16-review](../docs/reviews/16-review.md).

Повний фізичний цикл із гітарою/USB, курсор–звук, last-note tail, тривалі повтори, permissions та sleep/unplug залишені у U10/U01/U02/U03/U08/U09 до завершення 22 програмних задач. Статус `pending_user`; issue лишається відкритим.

Debug and Release native local .app builds pass with ad-hoc signing (`Scripts/build_local.py --configuration debug|release`).
